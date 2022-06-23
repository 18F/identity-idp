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
      const linkLang = link.getAttribute('lang');
      const prefix = linkLang === 'en' ? '' : `/${linkLang}`;
      const url = new URL(window.location.href);
      const { lang } = document.documentElement;
      const barePath = url.pathname.replace(new RegExp(`^/${lang}`), '');
      url.pathname = prefix + barePath;
      link.setAttribute('href', url.toString());
    });
  }

  const tearDown = ['pushState', 'replaceState'].reduce(
    (tearDownPrevious, functionName) => {
      const originalFunction = History.prototype[functionName];
      History.prototype[functionName] = function (...args) {
        const result = originalFunction.apply(this, args);
        syncLinkURLs();
        return result;
      };

      return () => {
        tearDownPrevious();
        History.prototype[functionName] = originalFunction;
      };
    },
    () => {},
  );

  window.addEventListener('popstate', syncLinkURLs);

  return tearDown;
}

if (process.env.NODE_ENV !== 'test') {
  setUp();
}
