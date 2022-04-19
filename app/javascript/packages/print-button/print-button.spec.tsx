import sinon from 'sinon';
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import PrintButton from './print-button';

describe('PrintButton', () => {
  const sandbox = sinon.createSandbox();

  beforeEach(() => {
    sandbox.stub(window, 'print');
  });

  afterEach(() => {
    sandbox.restore();
  });

  it('renders a button that prints when clicked', () => {
    const { getByRole } = render(<PrintButton />);

    const button = getByRole('button', { name: 'components.print_button.label' });

    userEvent.click(button);

    expect(window.print).to.have.been.called();
  });

  it('forwards all other props to the button child', () => {
    const { getByRole } = render(<PrintButton isOutline />);

    const button = getByRole('button', { name: 'components.print_button.label' });

    expect(button.closest('lg-print-button')).to.exist();
    expect(button.classList.contains('usa-button--outline')).to.be.true();
  });

  it('renders with print icon', () => {
    const { getByRole } = render(<PrintButton />);

    const icon = getByRole('img', { hidden: true });

    expect(icon.classList.contains('usa-icon')).to.be.true();
    expect(icon.querySelector('use[href$="#print"]'));
  });
});
