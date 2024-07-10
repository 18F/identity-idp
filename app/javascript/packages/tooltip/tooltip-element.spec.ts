import { screen, getByText, waitFor } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import { computeAccessibleDescription } from 'dom-accessibility-api';
import './tooltip-element';

describe('TooltipElement', () => {
  function createAndConnectElement({ tooltipText = '', innerHTML = '<span>Verified</span>' } = {}) {
    const element = document.createElement('lg-tooltip');
    element.setAttribute('tooltip-text', tooltipText);
    element.innerHTML = innerHTML;
    document.body.appendChild(element);
    return element;
  }

  it('initializes tooltip element', async () => {
    const tooltipText = 'Your identity has been verified';
    const element = createAndConnectElement({ tooltipText });

    const content = getByText(element, 'Verified');

    await userEvent.hover(content);
    expect(computeAccessibleDescription(content)).to.be.equal(tooltipText);
    await waitFor(() => {
      expect(screen.getByText(tooltipText).classList.contains('is-visible')).to.be.true();
    });
  });
});
