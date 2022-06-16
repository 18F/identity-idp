import { screen } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import { useSandbox } from '@18f/identity-test-helpers';
import * as analytics from '@18f/identity-analytics';

describe('backupCodeAnalytics', () => {
  const sandbox = useSandbox();

  beforeEach(async () => {
    document.body.innerHTML = `
      <a download="backup_codes.txt" class="usa-button usa-button--outline" href="#"><svg aria-hidden="true" focusable="false" role="img" class="usa-icon">
  <use href="http://test.host/assets/identity-style-guide/dist/assets/img/sprite-8eff3bf787e3ce0eab960fe5e9eccf4418d9af6a9f8c95a9ec9254aa778b2dbd.svg#file_download"></use>
</svg>Download</a>
    `;
    await import('../../../app/javascript/packs/backup-code-analytics');
  });

  afterEach(() => {
    sandbox.restore();
    delete require.cache[require.resolve('../../../app/javascript/packs/backup-code-analytics')];
  });

  it('adds an event listener to the download button', async () => {
    const test = sandbox.spy(analytics, 'trackEvent');
    await userEvent.click(screen.getByText('Download'));

    sandbox.assert.calledOnce(test);
    sandbox.assert.calledWith(test, 'Multi-Factor Authentication: download backup code');
  });
});
