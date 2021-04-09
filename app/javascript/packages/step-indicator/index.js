const SMALL_VIEWPORT_MEDIA_QUERY = '(max-width: 639px)';

class StepIndicator {
  /**
   * @param {HTMLDivElement} wrapper
   */
  constructor(wrapper) {
    this.elements = {
      wrapper,
      scroller: /** @type {HTMLDivElement} */ (wrapper.querySelector('.step-indicator__scroller')),
    };
  }

  get isSmallViewport() {
    return this.mediaQueryList ? this.mediaQueryList.matches : false;
  }

  bind() {
    this.mediaQueryList = window.matchMedia(SMALL_VIEWPORT_MEDIA_QUERY);
    this.mediaQueryList.addEventListener('change', () => this.onBreakpointMatchChange());
    this.onBreakpointMatchChange();
    if (this.isSmallViewport) {
      this.setScrollOffset();
    }
  }

  onBreakpointMatchChange() {
    this.toggleWrapperFocusable();
  }

  setScrollOffset() {
    const { scroller } = this.elements;
    const currentStepIndex = Array.from(scroller.children).findIndex((step) =>
      step.classList.contains('step-indicator__step--current'),
    );
    scroller.scrollLeft = Math.max((scroller.clientWidth / 3) * (currentStepIndex - 1), 0);
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
