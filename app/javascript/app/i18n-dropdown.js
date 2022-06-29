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

  /**
   * Loops through all of the language links in the dropdown and updates their target url
   * to reflect the correct route
   */
  function syncLanguageLinkURLs() {
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

  syncLanguageLinkURLs();

  window.addEventListener('lg:url-change', syncLanguageLinkURLs);
  return () => {
    window.removeEventListener('lg:url-change', syncLanguageLinkURLs);
  };
}

/**
 *  used to mock this behavior for testing purposes
 */
if (process.env.NODE_ENV !== 'test') {
  setUp();
}
