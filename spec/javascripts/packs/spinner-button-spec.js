import userEvent from '@testing-library/user-event';
import { SpinnerButton } from '../../../app/javascript/packs/spinner-button';

describe('SpinnerButton', () => {
  let wrapper;
  beforeEach(() => {
    wrapper = document.createElement('div');
    wrapper.innerHTML = `
      <div class="spinner-button">
        <div class="spinner-button__content">
          <a href="#">Click Me</a>
        </div>
        <img
          srcset="/assets/spinner@2x.gif 2x"
          height="144"
          width="144"
          alt=""
          aria-hidden="true"
          class="spinner-button__spinner usa-sr-only"
          src="/assets/spinner.gif">
      </div>
    `;
    wrapper = wrapper.firstElementChild;
  });

  it('shows spinner on click', () => {
    const { button, spinner } = new SpinnerButton(wrapper).elements;

    userEvent.click(button);

    expect(wrapper.classList.contains('spinner-button--spinner-active')).to.be.true();
    expect(spinner.classList.contains('usa-sr-only')).to.be.false();
  });
});
