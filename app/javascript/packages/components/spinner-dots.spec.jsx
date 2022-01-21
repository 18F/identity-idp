import { render } from '@testing-library/react';
import SpinnerDots from './spinner-dots';

describe('SpinnerDots', () => {
  it('renders dots', () => {
    const { container } = render(<SpinnerDots />);
    const dots = /** @type {HTMLElement} */ (container.firstElementChild);

    expect(dots.classList.contains('spinner-dots')).to.be.true();
    expect(dots.classList.contains('spinner-dots--centered')).to.be.false();
    expect(dots.getAttribute('aria-hidden')).to.equal('true');
  });

  it('adds class name when centered', () => {
    const { container } = render(<SpinnerDots isCentered />);
    const dots = /** @type {HTMLElement} */ (container.firstElementChild);

    expect(dots.classList.contains('spinner-dots--centered')).to.be.true();
  });

  it('applies a given className', () => {
    const { container } = render(<SpinnerDots className="example-class" />);
    const dots = /** @type {HTMLElement} */ (container.firstElementChild);

    expect(dots.classList.contains('example-class')).to.be.true();
  });
});
