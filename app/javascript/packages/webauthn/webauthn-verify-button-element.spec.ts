import sinon from 'sinon';
import quibble from 'quibble';
import { screen } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import type { WebauthnVerifyButtonDataset } from './webauthn-verify-button-element';

describe('WebauthnVerifyButtonElement', () => {
  const verifyWebauthnDevice = sinon.stub();

  before(async () => {
    quibble('./verify-webauthn-device', verifyWebauthnDevice);
    await import('./webauthn-verify-button-element');
  });

  beforeEach(() => {
    verifyWebauthnDevice.reset();
  });

  after(() => {
    quibble.reset();
  });

  function createElement(data?: Partial<WebauthnVerifyButtonDataset>) {
    document.body.innerHTML = `
      <form>
        <lg-webauthn-verify-button>
          <div class="webauthn-verify-button__spinner" hidden>
            <p>Authenticating</p>
          </div>
          <button type="button" class="webauthn-verify-button__button">
            Authenticate
          </button>
        </lg-webauthn-verify-button>
      </form>
    `;
    const element = document.querySelector('lg-webauthn-verify-button')!;
    Object.assign(element.dataset, { credentials: '[]', userChallenge: '[]' }, data);
    const form = document.querySelector('form')!;
    sinon.stub(form, 'submit');
    return { form, element };
  }

  it('shows spinner on click', async () => {
    createElement();

    expect(screen.queryByText('Authenticating')!.closest('[hidden]')).to.exist();

    const button = screen.getByRole('button', { name: 'Authenticate' });
    await userEvent.click(button);

    expect(screen.queryByText('Authenticating')!.closest('[hidden]')).to.not.exist();
  });

  it('passes data attributes to verify call', async () => {
    createElement({ userChallenge: '[1,2]', credentials: '[{}]' });

    expect(screen.queryByText('Authenticating')!.closest('[hidden]')).to.exist();

    const button = screen.getByRole('button', { name: 'Authenticate' });
    await userEvent.click(button);

    expect(verifyWebauthnDevice).to.have.been.calledWith({
      userChallenge: '[1,2]',
      credentials: [{}],
    });
  });

  it('submits with error name as input on thrown error', async () => {
    const { form } = createElement();

    class CustomError extends Error {
      name = 'CustomError';
    }
    verifyWebauthnDevice.throws(new CustomError());

    const button = screen.getByRole('button', { name: 'Authenticate' });
    await userEvent.click(button);
    await expect(form.submit).to.eventually.be.called();

    expect(Object.fromEntries(new FormData(form))).to.deep.equal({
      webauthn_error: 'CustomError',
    });
  });

  it('submits with verify result on successful verification', async () => {
    verifyWebauthnDevice.resolves({
      credentialId: Buffer.from('123', 'utf-8'),
      authenticatorData: Buffer.from('auth', 'utf-8'),
      clientDataJSON: Buffer.from('json', 'utf-8'),
      signature: Buffer.from('sig', 'utf-8'),
    });
    const { form } = createElement();

    const button = screen.getByRole('button', { name: 'Authenticate' });
    await userEvent.click(button);
    await expect(form.submit).to.eventually.be.called();

    expect(Object.fromEntries(new FormData(form))).to.deep.equal({
      credential_id: '123',
      authenticator_data: 'auth',
      client_data_json: 'json',
      signature: 'sig',
    });
  });
});
