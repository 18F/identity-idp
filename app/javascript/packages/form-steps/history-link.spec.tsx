import { render, fireEvent, createEvent } from '@testing-library/react';
import HistoryLink from './history-link';

describe('HistoryLink', () => {
  it('renders a link to the intended step', () => {
    const { getByRole } = render(<HistoryLink basePath="/base" step="step" />);

    const link = getByRole('link');

    expect(link.getAttribute('href')).to.equal('/base/step');
  });

  it('renders a visual button to the intended step', () => {
    const { getByRole } = render(<HistoryLink basePath="/base" step="step" isVisualButton isBig />);

    const link = getByRole('link');

    expect(link.getAttribute('href')).to.equal('/base/step');
    expect(link.classList.contains('usa-button')).to.be.true();
    expect(link.classList.contains('usa-button--big')).to.be.true();
  });

  it('intercepts navigation to route using client-side routing', () => {
    const { getByRole } = render(<HistoryLink step="step" />);

    const beforeHash = window.location.hash;
    const link = getByRole('link');

    const didPreventDefault = !fireEvent.click(link);

    expect(didPreventDefault).to.be.true();
    expect(window.location.hash).to.not.equal(beforeHash);
    expect(window.location.hash).to.equal('#step');
  });

  it('does not intercept navigation when holding modifier key', () => {
    const { getByRole } = render(<HistoryLink step="step" />);

    const beforeHash = window.location.hash;
    const link = getByRole('link');

    for (const mod of ['metaKey', 'shiftKey', 'ctrlKey', 'altKey']) {
      const didPreventDefault = !fireEvent.click(link, { [mod]: true });

      expect(didPreventDefault).to.be.false();
      expect(window.location.hash).to.equal(beforeHash);
    }
  });

  it('does not intercept navigation when clicking with other than main button', () => {
    const { getByRole } = render(<HistoryLink step="step" />);

    const beforeHash = window.location.hash;
    const link = getByRole('link');

    // Reference: https://developer.mozilla.org/en-US/docs/Web/API/MouseEvent/button#value
    for (const button of [1, 2, 3, 4]) {
      const didPreventDefault = !fireEvent.click(link, { button });

      expect(didPreventDefault).to.be.false();
      expect(window.location.hash).to.equal(beforeHash);
    }
  });

  it('does not intercept navigation if event was already default-prevented', () => {
    const { getByRole } = render(<HistoryLink step="step" />);

    const beforeHash = window.location.hash;
    const link = getByRole('link');
    const event = createEvent('click', link);
    event.preventDefault();

    fireEvent(link, event);

    expect(window.location.hash).to.equal(beforeHash);
  });
});
