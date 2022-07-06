import { initialize } from '../../../app/javascript/packs/verify-flow';

describe('verify-flow', () => {
  let tearDown;

  beforeEach(async () => {
    document.body.innerHTML = `
      <div
        id="app-root"
        data-initial-values="{}"
        data-enabled-step-names='["password_confirm"]'
        data-base-path="/"
        data-cancel-url="/"
        data-in-person-url="/"
        data-store-key="dK00lFMxejQH3y5BWt+LwOShw+WSRt/6OudNYI/N9X4="
      ></div>
    `;

    tearDown = await initialize();
  });

  afterEach(() => {
    tearDown();
  });

  it('clears session storage on session timeout', () => {
    expect(sessionStorage).to.have.lengthOf(1);

    window.dispatchEvent(new window.CustomEvent('lg:session-timeout'));

    expect(sessionStorage).to.have.lengthOf(0);
  });
});
