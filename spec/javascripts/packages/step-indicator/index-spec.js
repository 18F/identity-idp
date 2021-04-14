import StepIndicator from '@18f/identity-step-indicator';
import userEvent from '@testing-library/user-event';
import { useSandbox } from '../../support/sinon';

describe('StepIndicator', () => {
  const sandbox = useSandbox();

  beforeEach(() => {
    document.body.innerHTML = `
      <div role="region" aria-label="Step progress" class="step-indicator">
        <ol class="step-indicator__scroller">
          <li class="step-indicator__step">
            <span class="step-indicator__step-title">
              Step one
            </span>
            <span class="usa-sr-only">
              Completed
            </span>
          </li>
          <li class="step-indicator__step step-indicator__step--current">
            <span class="step-indicator__step-title">
              Step two
            </span>
            <span class="usa-sr-only">
              Current step
            </span>
          </li>
        </ol>
      </div>`;
  });

  function initialize() {
    const stepIndicator = new StepIndicator(document.body.firstElementChild);
    stepIndicator.bind();
    return stepIndicator;
  }

  context('small viewport', () => {
    beforeEach(() => {
      window.resizeTo(340, 600);
    });

    it('has focusable scroller', () => {
      const stepIndicator = initialize();
      userEvent.click(stepIndicator.elements.scroller);
      expect(document.activeElement).to.equal(stepIndicator.elements.scroller);
    });

    it('scrolls to current item', () => {
      const currentStep = document.querySelector('.step-indicator__step--current');
      sandbox.stub(currentStep, 'scrollIntoView');
      initialize();
      expect(currentStep.scrollIntoView).to.have.been.calledOnce();
    });

    it('makes scroller unfocusable when transitioning to large viewport', () => {
      const stepIndicator = initialize();
      window.resizeTo(1024, 768);
      userEvent.click(stepIndicator.elements.scroller);
      expect(document.activeElement).to.not.equal(stepIndicator.elements.scroller);
    });
  });

  context('large viewport', () => {
    beforeEach(() => {
      window.resizeTo(1024, 768);
    });

    it('does not have focusable scroller', () => {
      const stepIndicator = initialize();
      userEvent.click(stepIndicator.elements.scroller);
      expect(document.activeElement).to.not.equal(stepIndicator.elements.scroller);
    });

    it('makes scroller focusable when transitioning to small viewport', () => {
      const stepIndicator = initialize();
      window.resizeTo(340, 768);
      userEvent.click(stepIndicator.elements.scroller);
      expect(document.activeElement).to.equal(stepIndicator.elements.scroller);
    });
  });
});
