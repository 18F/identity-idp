import * as analytics from '@18f/identity-analytics';
import { useSandbox } from '@18f/identity-test-helpers';
import { initialize } from '../../../app/javascript/packs/mfa-more-options';

describe('mfa-more-options', () => {
  const sandbox = useSandbox();

  beforeEach(() => {
    sandbox.stub(analytics, 'trackEvent');
  });

  afterEach(() => {
    document.body.innerHTML = '';
  });

  const buildOptions = () => {
    document.body.innerHTML = `
      <div class="mfa-options" data-mfa-options>
        <div class="mfa-options__item"><button type="button">One</button></div>
        <div class="mfa-options__item"><button type="button">Two</button></div>
        <div class="mfa-options__item mfa-options__item--extra"><button type="button">Three</button></div>
        <button type="button" class="mfa-options__more" data-mfa-more>More options</button>
      </div>
    `;
    return {
      container: document.querySelector<HTMLElement>('[data-mfa-options]')!,
      button: document.querySelector<HTMLButtonElement>('[data-mfa-more]')!,
    };
  };

  it('logs an analytics event when the more options button is clicked', () => {
    const { button } = buildOptions();

    initialize();
    button.click();

    expect(analytics.trackEvent).to.have.been.calledOnceWith(
      'multi_factor_auth_more_options_clicked',
    );
  });

  it('expands the hidden options when the button is clicked', () => {
    const { container, button } = buildOptions();

    initialize();
    button.click();

    expect(container.classList.contains('mfa-options--expanded')).to.be.true();
  });

  it('does nothing when there is no more options button', () => {
    document.body.innerHTML = `
      <div class="mfa-options" data-mfa-options>
        <div class="mfa-options__item"><button type="button">One</button></div>
      </div>
    `;

    initialize();

    expect(analytics.trackEvent).not.to.have.been.called();
  });
});
