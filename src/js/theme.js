// Runs in <head>, before the page paints, so a saved theme never flashes the
// other one first. Every page includes it after its styles, which it reads
// for the browser's theme-color.
(function () {
  var key = 'theme';
  var root = document.documentElement;
  var system = window.matchMedia('(prefers-color-scheme: dark)');

  function saved() {
    try { return localStorage.getItem(key); } catch (e) { return null; }
  }
  function current() {
    return root.getAttribute('data-theme') || (system.matches ? 'dark' : 'light');
  }
  function apply(theme) {
    if (theme === 'light' || theme === 'dark') root.setAttribute('data-theme', theme);
    else root.removeAttribute('data-theme');
    var meta = document.querySelector('meta[name="theme-color"]');
    var bg = getComputedStyle(root).getPropertyValue('--bg').trim();
    if (meta && bg) meta.setAttribute('content', bg);
  }

  apply(saved());
  system.addEventListener('change', function () { apply(saved()); });

  document.addEventListener('DOMContentLoaded', function () {
    var btn = document.getElementById('theme-toggle');
    if (!btn) return;
    btn.addEventListener('click', function () {
      var next = current() === 'dark' ? 'light' : 'dark';
      try { localStorage.setItem(key, next); } catch (e) {}
      apply(next);
    });
  });
})();
