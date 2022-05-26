import baseUserEvent from '@testing-library/user-event';
import { render } from '@testing-library/react';
import { createRef } from 'react';
import { useSandbox } from '@18f/identity-test-helpers';
import { SpinnerButtonElement } from './spinner-button-element';
import SpinnerButton from './spinner-button';

describe('SpinnerButton', () => {
  const { clock } = useSandbox({ useFakeTimers: true });
  const userEvent = baseUserEvent.setup({ advanceTimers: clock.tick });

  it('renders a SpinnerButton', async () => {
    const { getByRole } = render(<SpinnerButton>Spin!</SpinnerButton>);

    const button = getByRole('button', { name: 'Spin!' }) as HTMLButtonElement;
    const spinner = button.closest('lg-spinner-button')!;

    await userEvent.click(button);

    expect(spinner.classList.contains('spinner-button--spinner-active')).to.be.true();
  });

  it('exposes SpinnerButtonElement instance via forwarded ref', () => {
    const ref = createRef<SpinnerButtonElement>();
    render(<SpinnerButton ref={ref} />);

    expect(ref.current).to.be.instanceOf(SpinnerButtonElement);
  });

  it('renders actionMessage as accessible message for click', async () => {
    const { getByRole } = render(
      <SpinnerButton longWaitDurationMs={1} actionMessage="Loading..." />,
    );

    const button = getByRole('button') as HTMLButtonElement;
    const status = getByRole('status');

    expect(status.textContent).to.be.empty();

    await userEvent.click(button);

    expect(status.textContent).not.to.be.empty();
    expect(status.classList.contains('usa-sr-only')).to.be.true();

    clock.tick(1);

    expect(status.textContent).not.to.be.empty();
    expect(status.classList.contains('usa-sr-only')).to.be.false();
  });

  it('forwards options for SpinnerButton', async () => {
    const { getByRole } = render(
      <SpinnerButton longWaitDurationMs={1} spinOnClick={false} actionMessage="Loading..." />,
    );

    const button = getByRole('button') as HTMLButtonElement;
    const spinner = button.closest('lg-spinner-button')!;
    const status = getByRole('status')!;

    await userEvent.click(button);

    expect(spinner.classList.contains('spinner-button--spinner-active')).to.be.false();

    spinner.toggleSpinner(true);
    clock.tick(1);
    expect(status.classList.contains('usa-sr-only')).to.be.false();
  });

  it('forwards additional props to Button', () => {
    const { getByRole } = render(<SpinnerButton isOutline />);

    const button = getByRole('button')!;

    expect(button.classList.contains('usa-button--outline')).to.be.true();
  });

  it('includes additional class for outline buttons', () => {
    const { getByRole } = render(<SpinnerButton isOutline />);

    const button = getByRole('button')!;
    const spinner = button.closest('lg-spinner-button')!;

    expect(spinner.classList.contains('spinner-button--outline')).to.be.true();
  });
});
