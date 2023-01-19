import { useSandbox } from '@18f/identity-test-helpers';
import './countdown-alert-element';
import './countdown-element';

describe('CountdownAlertElement', () => {
  const sandbox = useSandbox({ useFakeTimers: true });

  function createElement({
    showAtRemaining,
    redirectURL,
  }: { showAtRemaining?: number; redirectURL?: string } = {}) {
    document.body.innerHTML = `
      <lg-countdown-alert
        ${showAtRemaining ? `show-at-remaining="${showAtRemaining}"` : ''}
        ${redirectURL ? `redirect-url="${redirectURL}"` : ''}>
        <div class="usa-alert usa-alert--info margin-bottom-4 usa-alert--info-time" role="status">
          <div class="usa-alert__body">
            <p class="usa-alert__text">
              <lg-countdown
                data-expiration="2022-12-02T00:01:32Z"
                data-update-interval="1000"
                data-start-immediately="true"
              >
                1 minute and 45 seconds
              </lg-countdown>
            </p>
          </div>
        </div>
      </lg-countdown-alert>`;
    return document.querySelector('lg-countdown-alert')!;
  }

  beforeEach(() => {
    sandbox.clock.setSystemTime(new Date('2022-12-02T00:00:00Z'));
  });

  context('when shown at specific time remaining', () => {
    it('shows after time remaining reaches threshold', () => {
      const element = createElement({ showAtRemaining: 90000 });
      sandbox.spy(element, 'show');

      sandbox.clock.tick(1000);
      expect(element.show).not.to.have.been.called();

      sandbox.clock.tick(1000);
      expect(element.show).to.have.been.called();
    });
  });

  it('redirects when time has expired', () => {
    createElement({ redirectURL: '#teapot' });

    sandbox.clock.tick(91000);
    expect(window.location.hash).to.equal('');
    sandbox.clock.tick(1000);
    expect(window.location.hash).to.equal('#teapot');
  });
});
