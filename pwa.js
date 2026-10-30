/* LOQTA PWA: service worker + install banner */
(function () {
  if ('serviceWorker' in navigator) {
    addEventListener('load', function () { navigator.serviceWorker.register('sw.js').catch(function () {}); });
  }
  var KEY = 'loqta_install_dismissed', deferred = null, bar = null;
  var standalone = matchMedia('(display-mode: standalone)').matches || navigator.standalone;
  var ios = /iphone|ipad|ipod/i.test(navigator.userAgent) && !standalone;
  var native = !!(window.Capacitor && window.Capacitor.isNativePlatform && window.Capacitor.isNativePlatform());
  if (standalone || native || document.documentElement.hasAttribute('data-no-banner')) return;

  function dismissed() { try { return +localStorage.getItem(KEY) > Date.now(); } catch (e) { return false; } }
  function snooze() { try { localStorage.setItem(KEY, String(Date.now() + 7 * 864e5)); } catch (e) {} }
  function hide() { if (bar) { bar.remove(); bar = null; } }

  function show() {
    if (bar || dismissed()) return;
    bar = document.createElement('div');
    bar.setAttribute('role', 'dialog');
    bar.setAttribute('aria-label', 'تثبيت التطبيق');
    bar.dir = 'rtl';
    bar.style.cssText = 'position:fixed;inset-inline:12px;bottom:calc(12px + env(safe-area-inset-bottom,0px));z-index:90;max-width:520px;margin-inline:auto;background:#0D4F8B;color:#fff;border-radius:16px;padding:12px 14px;display:flex;align-items:center;gap:12px;box-shadow:0 8px 28px rgba(0,0,0,.35);font-family:"Readex Pro",Tahoma,sans-serif;line-height:1.4';
    bar.innerHTML = '<img src="icon-192.png" alt="" width="44" height="44" style="border-radius:10px;flex:none">' +
      '<div style="flex:1;min-width:0"><b style="font-size:15px">نزل تطبيق لقطة</b><div id="lq-sub" style="font-size:12px;opacity:.9">يومك لقطة مع لقطة، كل حاجة ب99 جنيه</div></div>' +
      '<button id="lq-ok" style="background:#FF7A00;color:#1A0E00;border:0;border-radius:10px;padding:9px 14px;font:inherit;font-weight:700;cursor:pointer;white-space:nowrap">تثبيت الآن</button>' +
      '<button id="lq-x" aria-label="إغلاق" style="background:none;border:0;color:#fff;font-size:20px;cursor:pointer;padding:4px 6px">✕</button>';
    document.body.appendChild(bar);
    bar.querySelector('#lq-x').onclick = function () { snooze(); hide(); };
    bar.querySelector('#lq-ok').onclick = function () {
      if (deferred) {
        deferred.prompt();
        deferred.userChoice.then(function (r) { deferred = null; if (r.outcome === 'accepted') hide(); else { snooze(); hide(); } });
      } else if (ios) {
        bar.querySelector('#lq-sub').textContent = 'دوس زر المشاركة ⬆️ ثم "إضافة إلى الشاشة الرئيسية"';
        bar.querySelector('#lq-ok').hidden = true;
      }
    };
  }

  addEventListener('beforeinstallprompt', function (e) { e.preventDefault(); deferred = e; if (document.body) show(); else addEventListener('DOMContentLoaded', show); });
  addEventListener('appinstalled', function () { deferred = null; hide(); });
  if (ios) addEventListener('load', function () { setTimeout(show, 1500); });
})();
