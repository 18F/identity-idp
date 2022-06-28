import { setUp } from '../../../app/javascript/app/i18n-dropdown';

describe('i18n-dropdown', () => {
  let tearDown;

  beforeEach(() => {
    document.body.innerHTML = `
      <div class="i18n-dropdown">
        <a href="/wrong" lang="en">English</a>
        <a href="/wrong" lang="fr">Français</a>
        <a href="/wrong" lang="es">Español</a>
      </div>
    `;

    tearDown = setUp();
  });

  afterEach(() => {
    tearDown();
  });

  context('with default language', () => {
    it('updates links on initialization', () => {
      expect(document.querySelector('a[lang="en"]').pathname).to.equal('/');
      expect(document.querySelector('a[lang="es"]').pathname).to.equal('/es/');
      expect(document.querySelector('a[lang="fr"]').pathname).to.equal('/fr/');
    });

    it('updates links on url change', () => {
      window.history.replaceState(null, '', '/foo');
      window.dispatchEvent(new window.CustomEvent('lg:url-change'));

      expect(document.querySelector('a[lang="en"]').pathname).to.equal('/foo');
      expect(document.querySelector('a[lang="es"]').pathname).to.equal('/es/foo');
      expect(document.querySelector('a[lang="fr"]').pathname).to.equal('/fr/foo');
    });
  });

  context('with non default language', () => {
    beforeEach(() => {
      document.documentElement.lang = 'fr';
    });

    it('updates links on initialization', () => {
      expect(document.querySelector('a[lang="en"]').pathname).to.equal('/');
      expect(document.querySelector('a[lang="es"]').pathname).to.equal('/es/');
      expect(document.querySelector('a[lang="fr"]').pathname).to.equal('/fr/');
    });

    it('updates links on url change', () => {
      window.history.replaceState(null, '', '/fr/bar');
      window.dispatchEvent(new window.CustomEvent('lg:url-change'));

      expect(document.querySelector('a[lang="en"]').pathname).to.equal('/bar');
      expect(document.querySelector('a[lang="es"]').pathname).to.equal('/es/bar');
      expect(document.querySelector('a[lang="fr"]').pathname).to.equal('/fr/bar');
    });
  });
});
