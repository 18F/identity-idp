import { setUp } from '../../../app/javascript/app/i18n-dropdown';
import sinon from 'sinon';

describe('i18n-dropdown', () => {
  let tearDown;

  before(() => {
    const sandbox = sinon.createSandbox();

    // const history = ['example.com'];

    // sandbox.stub(window, 'history').value(
    //   Object.assign(history, {
    //     pushState(_data, _unused, url) {
    //       history.push(url);
    //     },
    //     replaceState(_data, _unused, url) {
    //       history[history.length - 1] = url;
    //     },
    //     back() {
    //       history.pop();
    //       window.dispatchEvent(new CustomEvent('popstate'));
    //     },
    //   }),
    // );

    tearDown = setUp();
  });

  after(() => {
    tearDown();
  });

  beforeEach(() => {
    document.body.innerHTML = `
    <div class="i18n-dropdown">
      <a href="/" lang="en">English</a>
      <a href="/" lang="fr">Français</a>
      <a href="/" lang="es">Español</a>
    </div>
  `;
  });

  context('using history.pushState ', () => {
    it('updates links with default language', () => {
      window.history.pushState(null, '', '/foo');
      console.log('pathname', document.querySelectorAll('a[lang="en"]')[0].href);
      expect(document.querySelectorAll('a[lang="en"]')[0].pathname).to.equal('/foo');
      expect(document.querySelectorAll('a[lang="es"]')[0].pathname).to.equal('/es/foo');
      expect(document.querySelectorAll('a[lang="fr"]')[0].pathname).to.equal('/fr/foo');
    });
    it('updates links with non default language', () => {
      window.history.pushState(null, '', '/fr/bar');
      expect(document.querySelectorAll('a[lang="en"]')[0].pathname).to.equal('/bar');
      expect(document.querySelectorAll('a[lang="es"]')[0].pathname).to.equal('/es/bar');
      expect(document.querySelectorAll('a[lang="fr"]')[0].pathname).to.equal('/fr/bar');
    });
  });

  context('updates links on popstate event', () => {
    it('updates links with default language', () => {
      window.history.pushState(null, '', '/foo');
      console.log('window url', window.location.href);
      history.back();
      console.log('window url', window.location.href);
      expect(document.querySelectorAll('a[lang="es"]')[0].pathname).to.equal('/es');
      expect(document.querySelectorAll('a[lang="en"]')[0].pathname).to.equal('/');
      expect(document.querySelectorAll('a[lang="fr"]')[0].pathname).to.equal('/fr');
    });
    it('updates links with non default language', () => {
      window.history.pushState(null, '', '/es/foo');
      console.log('window url', window.location.href);
      history.back();
      console.log('window url', window.location.href);
      expect(document.querySelectorAll('a[lang="es"]')[0].pathname).to.equal('/es');
      expect(document.querySelectorAll('a[lang="en"]')[0].pathname).to.equal('/');
      expect(document.querySelectorAll('a[lang="fr"]')[0].pathname).to.equal('/fr');
    });
  });
});
