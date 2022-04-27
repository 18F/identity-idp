import sinon from 'sinon';
import { screen } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import './print-button-element';

describe('PrintButtonElement', () => {
  const sandbox = sinon.createSandbox();

  beforeEach(() => {
    sandbox.stub(window, 'print');
  });

  afterEach(() => {
    sandbox.restore();
  });

  it('prints when clicked', async () => {
    document.body.innerHTML = `<lg-print-button><button type="button">Print</button><lg-print-button>`;
    const button = screen.getByRole('button');

    await userEvent.click(button);

    expect(window.print).to.have.been.called();
  });
});
