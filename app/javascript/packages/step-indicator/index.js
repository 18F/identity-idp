const SMALL_VIEWPORT_MEDIA_QUERY = '(max-width: 639px)';

class StepIndicator {
  /**
   * @param {HTMLElement} wrapper
   */
  constructor(wrapper) {
    this.elements = {
      wrapper,
      scroller: /** @type {HTMLElement} */ (wrapper.querySelector('.step-indicator__scroller')),
      currentStep: /** @type {HTMLElement?} */ (
        wrapper.querySelector('.step-indicator__step--current')
      ),
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
    const { currentStep, scroller } = this.elements;
    if (currentStep) {
      const scrollerPaddingLeft = parseInt(window.getComputedStyle(scroller).paddingLeft, 10);
      const { scrollWidth: scrollerScrollWidth, clientWidth: scrollerClientWidth } = scroller;
      const { offsetLeft: currentStepOffsetLeft } = currentStep;
      scroller.scrollLeft =
        currentStepOffsetLeft -
        scrollerPaddingLeft -
        (scrollerScrollWidth - scrollerClientWidth) / 2;
    }
  }

  /**
   * Toggles the scrollable region to be focusable at small viewports where the contents are in-
   * fact scrollable. This ensures that those who navigate using a keyboard are able to scroll the
   * content.
   *
   * @see https://dequeuniversity.com/rules/axe/4.0/scrollable-region-focusable
   */
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
