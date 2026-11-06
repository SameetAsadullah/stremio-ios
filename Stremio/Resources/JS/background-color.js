(function () {
  function report() {
    try {
      var el = document.querySelector('#root, .app, body') || document.body;
      var c = getComputedStyle(el).backgroundColor;
      if (c && c !== 'rgba(0, 0, 0, 0)' && c !== 'transparent') {
        window.webkit.messageHandlers.bg.postMessage(c);
      }
    } catch (e) {}
  }
  report(); setTimeout(report, 800); setTimeout(report, 2500);
})();
