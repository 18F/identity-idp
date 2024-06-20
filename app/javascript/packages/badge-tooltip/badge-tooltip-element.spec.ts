import { getByText } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import { computeAccessibleDescription } from 'dom-accessibility-api';
import './badge-tooltip-element';

describe('BadgeTooltipElement', () => {
  function createAndConnectElement({ tooltipText = '' } = {}) {
    const element = document.createElement('lg-badge-tooltip');
    element.setAttribute('tooltip-text', tooltipText);
    element.setAttribute('tooltip-text', 'Your identity has been verified');
    element.innerHTML = '<div class="lg-verification-badge usa-tooltip">Verified</div>';
    document.body.appendChild(element);
    return element;
  }

  it('shows a tooltip when mouseover, until mouseout', async () => {
    const element = createAndConnectElement();

    const badge = getByText(element, 'Verified');

    await userEvent.hover(badge);
    expect(computeAccessibleDescription(badge)).to.be.equal('Your identity has been verified');

    await userEvent.unhover(badge);
    expect(computeAccessibleDescription(badge)).to.be.equal('');
  });
});
