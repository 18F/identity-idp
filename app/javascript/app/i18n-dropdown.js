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

  function syncLanguageLinkURLs() {
    const links = document.querySelectorAll('.i18n-dropdown a[lang]');
    // const langArray = ['es', 'fr'];
    links.forEach((link) => {
      //1. url is /foo , lang is es   //2 url is /es/foo, lang is fr
      const lang = link.getAttribute('lang');
      let prefix = '';
      if (lang !== 'en') {
        prefix = `/${lang}`; //1. es is not en so we make prefix /es/foo   //2 lang is not en so prefix is fr
      }
      const url = new URL(window.location.href);
      // langArray.forEach((oldLang) => {
      //   url.pathname = prefix + url.pathname.replace(oldLang, '');
      // })
      link.setAttribute('href', url.toString()); //1. pathname becomes /es/foo    //2. pathname becomes /es/fr/foo because current url has /es
      if (window.location.pathname.includes(`/${lang}/`)) {
        //1. current url (/foo) does NOT include es so we skip  //2. current url does NOT have fr so we skip
        link.setAttribute('href', window.location.href);
      }
    });
  }

  const originalPushState = History.prototype.pushState;
  History.prototype.pushState = function (...args) {
    const result = originalPushState.apply(this, args);
    syncLanguageLinkURLs();
    return result;
  };
  window.addEventListener('popstate', syncLanguageLinkURLs);

  return () => {
    History.prototype.pushState = originalPushState;
  };
}

if (process.env.NODE_ENV !== 'test') {
  setUp();
}
