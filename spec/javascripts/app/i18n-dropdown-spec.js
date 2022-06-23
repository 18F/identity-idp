import sinon from 'sinon';
import { useDefineProperty } from '@18f/identity-test-helpers';
import { setUp } from '../../../app/javascript/app/i18n-dropdown';

describe('i18n-dropdown', () => {
  const sandbox = sinon.createSandbox();
  const defineProperty = useDefineProperty();

  let tearDown;

  beforeEach(() => {
    document.body.innerHTML = `
      <div class="i18n-dropdown">
        <a href="/" lang="en">English</a>
        <a href="/" lang="fr">Français</a>
        <a href="/" lang="es">Español</a>
      </div>
    `;

    const history = [window.location.href];
    defineProperty(window, 'location', {
      value: {
        get href() {
          return history[history.length - 1];
        },
      },
    });
    sandbox.stub(History.prototype, 'pushState').callsFake((_data, _unused, url) => {
      history.push(new URL(url, window.location.href).toString());
    });
    sandbox.stub(History.prototype, 'replaceState').callsFake((_data, _unused, url) => {
      history.push(new URL(url, window.location.href).toString());
    });
    sandbox.stub(History.prototype, 'back').callsFake(() => {
      history.pop();
      window.dispatchEvent(new CustomEvent('popstate'));
    });

    tearDown = setUp();
  });

  afterEach(() => {
    tearDown();
    sandbox.restore();
  });

  describe('using history.pushState', () => {
    context('with default language', () => {
      it('updates links', () => {
        window.history.pushState(null, '', '/foo');

        expect(document.querySelector('a[lang="en"]').pathname).to.equal('/foo');
        expect(document.querySelector('a[lang="es"]').pathname).to.equal('/es/foo');
        expect(document.querySelector('a[lang="fr"]').pathname).to.equal('/fr/foo');
      });
    });

    context('with non default language', () => {
      beforeEach(() => {
        document.documentElement.lang = 'fr';
      });

      it('updates links', () => {
        window.history.pushState(null, '', '/fr/bar');

        expect(document.querySelector('a[lang="en"]').pathname).to.equal('/bar');
        expect(document.querySelector('a[lang="es"]').pathname).to.equal('/es/bar');
        expect(document.querySelector('a[lang="fr"]').pathname).to.equal('/fr/bar');
      });
    });
  });

  describe('using history.replaceState', () => {
    context('with default language', () => {
      it('updates links', () => {
        window.history.replaceState(null, '', '/foo');

        expect(document.querySelector('a[lang="en"]').pathname).to.equal('/foo');
        expect(document.querySelector('a[lang="es"]').pathname).to.equal('/es/foo');
        expect(document.querySelector('a[lang="fr"]').pathname).to.equal('/fr/foo');
      });
    });

    context('with non default language', () => {
      beforeEach(() => {
        document.documentElement.lang = 'fr';
      });

      it('updates links', () => {
        window.history.replaceState(null, '', '/fr/bar');

        expect(document.querySelector('a[lang="en"]').pathname).to.equal('/bar');
        expect(document.querySelector('a[lang="es"]').pathname).to.equal('/es/bar');
        expect(document.querySelector('a[lang="fr"]').pathname).to.equal('/fr/bar');
      });
    });
  });

  describe('updates links on popstate event', () => {
    context('with default language', () => {
      it('updates links', () => {
        window.history.pushState(null, '', '/foo');
        window.history.back();

        expect(document.querySelector('a[lang="en"]').pathname).to.equal('/');
        expect(document.querySelector('a[lang="es"]').pathname).to.equal('/es/');
        expect(document.querySelector('a[lang="fr"]').pathname).to.equal('/fr/');
      });
    });

    context('with non default language', () => {
      beforeEach(() => {
        document.documentElement.lang = 'fr';
      });

      it('updates links', () => {
        window.history.pushState(null, '', '/fr/foo');
        window.history.back();

        expect(document.querySelector('a[lang="en"]').pathname).to.equal('/');
        expect(document.querySelector('a[lang="es"]').pathname).to.equal('/es/');
        expect(document.querySelector('a[lang="fr"]').pathname).to.equal('/fr/');
      });
    });
  });
});
