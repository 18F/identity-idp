import { setUp } from '../../../app/javascript/app/i18n-dropdown';

describe('i18n-dropdown', () => {
  let tearDown;

  before(() => {
    document.body.innerHTML = `
      <div class="i18n-dropdown">
        <a href="/" href="en">English</a>
        <a href="/" lang="fr">Français</a>
      </div>
    `; // TODO

    tearDown = setUp();
  });

  after(() => {
    tearDown();
  });

  it('updates links on History#pushState', () => {
    // TODO
  });

  it('updates links on popstate event', () => {
    // TODO
  });
});
