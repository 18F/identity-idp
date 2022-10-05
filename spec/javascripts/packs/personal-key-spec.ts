import { screen } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import { useSandbox } from '@18f/identity-test-helpers';
import * as analytics from '@18f/identity-analytics';

describe('personal key', () => {
  const sandbox = useSandbox();

  beforeEach(async () => {
    document.body.innerHTML = `
      <a download="backup_codes.txt" class="usa-button usa-button--outline" href="#"><svg aria-hidden="true" focusable="false" role="img" class="usa-icon">
  <use href="http://test.host/assets/identity-style-guide/dist/assets/img/sprite-8eff3bf787e3ce0eab960fe5e9eccf4418d9af6a9f8c95a9ec9254aa778b2dbd.svg#file_download"></use>
</svg>Download</a>
    `;
    await import('../../../app/javascript/packs/personal-key-page-controller');
  });

  afterEach(() => {
    sandbox.restore();
    delete require.cache[require.resolve('../../../app/javascript/packs/personal-key-page-controller')];
  });

  it('adds an event listener to the download button', async () => {
    const test = sandbox.spy(analytics, 'trackEvent');
    await userEvent.click(screen.getElementById('acknowledgment'));
    await userEvent.click(screen.getElementById('acknowledgment'));

    sandbox.assert.calledTwice(test);
    sandbox.assert.calledWith(test, 'IdV: personal key acknowledged');
    sandbox.assert.calledWith(test, 'IdV: personal key un-acknowledged');
  });
});
