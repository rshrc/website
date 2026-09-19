      // Hover cards for links. The text is baked into the page at build time
      // by tool/homegen.rb (essay openings, any `preview` in the YAML sections,
      // and Spotify titles). The only thing fetched is a Spotify cover, from
      // this site, the first time its card opens.
      (function () {
        var data = document.getElementById('link-previews');
        if (!data || !window.matchMedia('(hover: hover) and (pointer: fine)').matches) return;

        var previews = JSON.parse(data.textContent);
        var siteHosts = [location.hostname, 'banerjeerishi.com', 'www.banerjeerishi.com'];

        // Links on this site are keyed by path, links elsewhere by full URL.
        // External keys go through URL() so they match the browser's own
        // normalised a.href.
        var external = {};
        Object.keys(previews).forEach(function (key) {
          if (key.charAt(0) !== '/') {
            try { external[new URL(key).href] = previews[key]; } catch (e) {}
          }
        });

        function previewFor(a) {
          var url;
          try { url = new URL(a.href); } catch (e) { return null; }
          if (siteHosts.indexOf(url.hostname) !== -1) return previews[url.pathname] || null;
          return external[url.href] || null;
        }

        var card = document.createElement('div');
        var cover = document.createElement('img');
        var text = document.createElement('p');
        var meta = document.createElement('p');
        card.className = 'preview';
        card.id = 'link-preview';
        card.setAttribute('role', 'tooltip');
        cover.className = 'preview-cover';
        cover.alt = '';
        text.className = 'preview-text';
        meta.className = 'preview-meta';
        card.appendChild(cover);
        card.appendChild(text);
        card.appendChild(meta);
        document.body.appendChild(card);

        var showTimer, hideTimer, current = null;

        // Below the link, left-aligned with it; flipped above when there is
        // no room underneath, and kept inside the viewport either way.
        function place(a) {
          var r = a.getBoundingClientRect();
          var w = card.offsetWidth, h = card.offsetHeight;
          var left = Math.min(Math.max(8, r.left), window.innerWidth - w - 8);
          var top = r.bottom + 8;
          if (top + h > window.innerHeight - 8 && r.top - h - 8 > 8) top = r.top - h - 8;
          card.style.left = (left + window.scrollX) + 'px';
          card.style.top = (top + window.scrollY) + 'px';
        }

        function show(a) {
          var p = previewFor(a);
          if (!p) return;
          clearTimeout(hideTimer);
          if (current && current !== a) current.removeAttribute('aria-describedby');
          // Covers load only when their card is first shown.
          if (p.i) cover.src = p.i;
          card.classList.toggle('has-cover', !!p.i);
          text.textContent = p.e;
          meta.textContent = p.m || '';
          meta.hidden = !p.m;
          place(a);
          a.setAttribute('aria-describedby', 'link-preview');
          card.classList.add('is-visible');
          current = a;
        }

        function hide() {
          clearTimeout(showTimer);
          card.classList.remove('is-visible');
          if (current) current.removeAttribute('aria-describedby');
          current = null;
        }

        [].forEach.call(document.querySelectorAll('a[href]'), function (a) {
          if (!previewFor(a)) return;
          a.addEventListener('mouseenter', function () {
            clearTimeout(hideTimer);
            clearTimeout(showTimer);
            // A short pause before the first card, so sweeping the mouse
            // across a list doesn't flash one; instant once one is open.
            showTimer = setTimeout(function () { show(a); }, current ? 0 : 250);
          });
          a.addEventListener('mouseleave', function () {
            clearTimeout(showTimer);
            hideTimer = setTimeout(hide, 80);
          });
          a.addEventListener('focus', function () { show(a); });
          a.addEventListener('blur', hide);
        });

        document.addEventListener('keydown', function (e) {
          if (e.key === 'Escape') hide();
        });
      })();
