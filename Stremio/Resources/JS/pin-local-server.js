(function () {
  try {
    var U = 'http://127.0.0.1:11470/';
    var raw = localStorage.getItem('profile');
    if (raw) {
      var p = JSON.parse(raw); p.settings = p.settings || {};
      if (p.settings.streamingServerUrl !== U) { p.settings.streamingServerUrl = U; localStorage.setItem('profile', JSON.stringify(p)); }
    }
  } catch (e) {}
})();
