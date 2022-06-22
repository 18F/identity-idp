export function setUp() {
  const mobileLink = document.querySelector('.i18n-mobile-toggle > button');
  const mobileDropdown = document.querySelector('.i18n-mobile-dropdown');
  const desktopLink = document.querySelector('.i18n-desktop-toggle > button');
  const desktopDropdown = document.querySelector('.i18n-desktop-dropdown');

  function addListenerMulti(el, s, fn) {
    s.split(' ').forEach((e) => el.addEventListener(e, fn, false));
  }

  function toggleAriaExpanded(element) {
    if (element.getAttribute('aria-expanded') === 'true') {
      element.setAttribute('aria-expanded', 'false');
    } else {
      element.setAttribute('aria-expanded', 'true');
    }
  }

  function languagePicker(trigger, dropdown) {
    addListenerMulti(trigger, 'click keypress', function (event) {
      const eventType = event.type;

      event.preventDefault();
      if (eventType === 'click' || (eventType === 'keypress' && event.which === 13)) {
        this.parentNode.classList.toggle('focused');
        dropdown.classList.toggle('display-none');
        toggleAriaExpanded(this);
      }
    });
  }

  if (desktopLink) {
    languagePicker(desktopLink, desktopDropdown);
  }
  if (mobileLink) {
    languagePicker(mobileLink, mobileDropdown);
  }

  function syncLinkURLs() {
    const links = document.querySelectorAll('.i18n-dropdown a[lang]');
    links.forEach((link) => {
      const lang = link.getAttribute('lang');
      let prefix = '';
      if (lang !== 'en') {
        prefix = `/${lang}`;
      }
      const url = new URL(window.location.href);
      url.pathname = prefix + url.pathname;
      link.setAttribute('href', url.toString());
    });
  }

  const originalPushState = History.prototype.pushState;
  History.prototype.pushState = function (...args) {
    const result = originalPushState.apply(this, args);
    syncLinkURLs();
    return result;
  };
  window.addEventListener('popstate', syncLinkURLs);

  return () => {
    History.prototype.pushState = originalPushState;
  };
}

if (process.env.NODE_ENV !== 'test') {
  setUp();
}
