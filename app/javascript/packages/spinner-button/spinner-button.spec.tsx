import sinon from 'sinon';
import baseUserEvent from '@testing-library/user-event';
import { render } from '@testing-library/react';
import { createRef } from 'react';
import { SpinnerButtonElement } from './spinner-button-element';
import SpinnerButton from './spinner-button';

describe('SpinnerButton', () => {
  const sandbox = sinon.createSandbox();
  const userEvent = baseUserEvent.setup({ advanceTimers: (ms: number) => sandbox.clock.tick(ms) });

  beforeEach(() => {
    sandbox.useFakeTimers();
  });

  afterEach(() => {
    sandbox.restore();
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

    sandbox.clock.tick(1);

    expect(status.textContent).not.to.be.empty();
    expect(status.classList.contains('usa-sr-only')).to.be.false();
  });
});
