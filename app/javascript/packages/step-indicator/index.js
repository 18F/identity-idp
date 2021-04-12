const SMALL_VIEWPORT_MEDIA_QUERY = '(max-width: 639px)';

class StepIndicator {
  /**
   * @param {HTMLElement} wrapper
   */
  constructor(wrapper) {
    this.elements = {
      wrapper,
      scroller: /** @type {HTMLElement} */ (wrapper.querySelector('.step-indicator__scroller')),
      currentStep: /** @type {HTMLElement?} */ (wrapper.querySelector(
        '.step-indicator__step--current',
      )),
    };
  }

  get isSmallViewport() {
    return this.mediaQueryList ? this.mediaQueryList.matches : false;
  }

  bind() {
    this.mediaQueryList = window.matchMedia(SMALL_VIEWPORT_MEDIA_QUERY);
    this.mediaQueryList.addListener(() => this.onBreakpointMatchChange());
    this.onBreakpointMatchChange();
    if (this.isSmallViewport) {
      this.setScrollOffset();
    }
  }

  onBreakpointMatchChange() {
    this.toggleWrapperFocusable();
  }

  setScrollOffset() {
    const { currentStep } = this.elements;
    if (currentStep) {
      currentStep.scrollIntoView({ inline: 'center' });
    }
  }

  toggleWrapperFocusable() {
    const { scroller } = this.elements;
    if (this.isSmallViewport) {
      scroller.setAttribute('tabindex', '0');
    } else {
      scroller.removeAttribute('tabindex');
    }
  }
}

export default StepIndicator;
