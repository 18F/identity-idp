import StepIndicator from '@18f/identity-step-indicator';
import userEvent from '@testing-library/user-event';
import { useSandbox } from '../../support/sinon';
import useDefineProperty from '../../support/define-property';

describe('StepIndicator', () => {
  const sandbox = useSandbox();
  const defineProperty = useDefineProperty();

  function initialize({ currentStepIndex = 0 } = {}) {
    document.body.innerHTML = `
      <div role="region" aria-label="Step progress" class="step-indicator">
        <ol class="step-indicator__scroller">
          ${Array.from(Array(5))
            .map(
              (_value, index) => `
            <li class="step-indicator__step ${
              currentStepIndex === index ? 'step-indicator__step--current' : ''
            } ">
              <span class="step-indicator__step-title">
                Step
              </span>
            </li>
          `,
            )
            .join('')}
        </ol>
      </div>`;
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
      sandbox.stub(window, 'getComputedStyle').callsFake((element) => ({
        paddingLeft: element.classList.contains('step-indicator__scroller') ? '24px' : '0',
      }));
      defineProperty(window.Element.prototype, 'scrollWidth', {
        get() {
          return this.classList.contains('step-indicator__scroller') ? 593 : 0;
        },
      });
      defineProperty(window.Element.prototype, 'clientWidth', {
        get() {
          return this.classList.contains('step-indicator__scroller') ? 375 : 0;
        },
      });
      defineProperty(window.HTMLElement.prototype, 'offsetLeft', {
        get() {
          return this.classList.contains('step-indicator__step--current')
            ? Array.from(this.parentNode.children).indexOf(this) * 109 + 24
            : 0;
        },
      });

      let stepIndicator;
      stepIndicator = initialize({ currentStepIndex: 0 });
      expect(stepIndicator.elements.scroller.scrollLeft).to.equal(-109);
      stepIndicator = initialize({ currentStepIndex: 1 });
      expect(stepIndicator.elements.scroller.scrollLeft).to.equal(0);
      stepIndicator = initialize({ currentStepIndex: 2 });
      expect(stepIndicator.elements.scroller.scrollLeft).to.equal(109);
      stepIndicator = initialize({ currentStepIndex: 3 });
      expect(stepIndicator.elements.scroller.scrollLeft).to.equal(218);
      stepIndicator = initialize({ currentStepIndex: 4 });
      expect(stepIndicator.elements.scroller.scrollLeft).to.equal(327);
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
