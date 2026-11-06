// Injected into every page. Stremio plays through MSE (a blob: <video> source)
// backed by the server's /hlsv2/ ffmpeg transcode, which is slow and stalls.
// We watch fetch/XHR for that transcode request, pull out the RAW file URL it
// wraps (the mediaURL= param), and hand THAT to native VLC — VLC decodes any
// codec directly, skipping the transcode entirely. Plain <video src> (direct,
// non-transcoded content) is caught as a fallback.
(function () {
  if (window.__vlcHook) return; window.__vlcHook = true;

  function toNative(url, title, time) {
    try {
      if (!url || url.indexOf('http') !== 0) return;
      window.webkit.messageHandlers.vlc.postMessage(
        JSON.stringify({ url: url, title: title || document.title || 'Stream', time: time || 0 })
      );
    } catch (e) {}
  }

  // Watch progress. The web player never plays, so the app reports VLC's position to Stremio's
  // core with the same actions the web player sends. The core saves it to the library item,
  // which feeds Continue Watching and resume. Times are in milliseconds.
  function dispatchPlayer(args) {
    try { if (window.core) window.core.dispatch({ action: 'Player', args: args }, 'player'); } catch (e) {}
  }
  window.__stremioVLC = {
    time: function (time, duration) {
      dispatchPlayer({ action: 'TimeChanged', args: { time: time, duration: duration, device: 'VLC' } });
    },
    // TimeChanged only moves the saved position forward. Seek sets it in both directions.
    seek: function (time, duration) {
      dispatchPlayer({ action: 'Seek', args: { time: time, duration: duration, device: 'VLC' } });
    },
    paused: function (paused) { dispatchPlayer({ action: 'PausedChanged', args: { paused: paused } }); },
    ended: function () { dispatchPlayer({ action: 'Ended' }); }
  };

  // The saved position, read the same way the web player does: only when the library item's
  // last video is the one about to play.
  function resumeTime() {
    var read = Promise.resolve(window.core ? window.core.getState('player') : null).then(function (p) {
      var item = p && p.libraryItem, req = p && p.selected && p.selected.streamRequest;
      if (item && item.state && req && req.path && item.state.video_id === req.path.id) {
        return item.state.timeOffset || 0;
      }
      return 0;
    });
    var timeout = new Promise(function (resolve) { setTimeout(function () { resolve(0); }, 1500); });
    return Promise.race([read, timeout]).catch(function () { return 0; });
  }

  // Stremio's subtitle addons answer .../subtitles/<type>/<id>...json with
  // { subtitles: [{ lang, url }] }. The web player would use them; VLC can't
  // see them, so relay the list to native and load them as playback slaves.
  function isSubs(u) { return typeof u === 'string' && u.indexOf('/subtitles/') !== -1; }
  function postSubs(json) {
    try {
      var list = (json && json.subtitles) || [], items = [];
      for (var i = 0; i < list.length; i++) {
        var t = list[i]; if (!t || !t.url) continue;
        items.push({ lang: t.lang || t.language || '', url: t.url });
      }
      if (items.length) window.webkit.messageHandlers.vlc.postMessage(JSON.stringify({ kind: 'subtitles', items: items }));
    } catch (e) {}
  }

  function isHls(u) {
    return typeof u === 'string' && u.indexOf('/hlsv2/') !== -1 && u.indexOf('.m3u8') !== -1;
  }

  function rawFromHls(u) {
    var key = 'mediaURL=';
    var i = u.indexOf(key);
    if (i === -1) return null;
    var rest = u.substring(i + key.length);
    var amp = rest.indexOf('&');
    if (amp !== -1) rest = rest.substring(0, amp);
    try { return decodeURIComponent(rest); } catch (e) { return rest; }
  }

  // Kill the web player so the server never starts the ffmpeg transcode: pause,
  // mute, and drop any /hlsv2 <video> source (which would keep transcoding).
  function stopWeb() {
    try {
      var vids = document.getElementsByTagName('video');
      for (var i = 0; i < vids.length; i++) {
        var v = vids[i];
        try {
          v.pause(); v.muted = true; v.removeAttribute('autoplay');
          if (v.src && v.src.indexOf('/hlsv2/') !== -1) { v.removeAttribute('src'); v.load(); }
        } catch (_) {}
      }
    } catch (e) {}
  }

  function grab(u) {
    var raw = rawFromHls(u) || u;
    resumeTime().then(function (time) { toNative(raw, null, time); });
    stopWeb(); setTimeout(stopWeb, 300); setTimeout(stopWeb, 1200);
  }

  // fetch: intercept AND block the transcode manifest.
  var origFetch = window.fetch;
  if (origFetch) {
    window.fetch = function (input, init) {
      var u = (typeof input === 'string') ? input : (input && input.url);
      if (isHls(u)) { grab(u); return Promise.reject(new DOMException('handled by native player', 'AbortError')); }
      if (isSubs(u)) {
        return origFetch.apply(this, arguments).then(function (r) {
          try { r.clone().json().then(postSubs).catch(function () {}); } catch (e) {}
          return r;
        });
      }
      return origFetch.apply(this, arguments);
    };
  }

  // XHR: same — mark in open(), then no-op the send() so it never hits the server.
  var origOpen = XMLHttpRequest.prototype.open;
  var origSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function (method, url) {
    this.__hls = isHls(url); this.__subs = isSubs(url); this.__url = url;
    return origOpen.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function () {
    if (this.__hls) { grab(this.__url); return; }
    if (this.__subs) {
      this.addEventListener('load', function () { try { postSubs(JSON.parse(this.responseText)); } catch (e) {} });
    }
    return origSend.apply(this, arguments);
  };

  // Fallback for direct (non-transcoded) <video src>.
  var P = HTMLMediaElement.prototype, origPlay = P.play;
  P.play = function () {
    var src = this.currentSrc || this.src;
    if (src && src.indexOf('blob:') !== 0 && src.indexOf('http') === 0) {
      if (src.indexOf('/hlsv2/') !== -1) { grab(src); try { this.removeAttribute('src'); this.load(); } catch (e) {} }
      else { toNative(src); try { this.pause(); this.muted = true; } catch (e) {} }
      return Promise.resolve();
    }
    return origPlay.apply(this, arguments);
  };
})();
