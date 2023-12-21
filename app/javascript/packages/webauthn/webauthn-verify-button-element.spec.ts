import sinon from 'sinon';
import quibble from 'quibble';
import { screen } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import '@18f/identity-submit-button/submit-button-element';
import { SCREEN_LOCK_ERROR } from './is-user-verification-screen-lock-error';
import type { WebauthnVerifyButtonDataset } from './webauthn-verify-button-element';

describe('WebauthnVerifyButtonElement', () => {
  const verifyWebauthnDevice = sinon.stub();
  const trackError = sinon.stub();

  before(async () => {
    quibble('./verify-webauthn-device', verifyWebauthnDevice);
    quibble('@18f/identity-analytics', { trackError });
    await import('./webauthn-verify-button-element');
  });

  beforeEach(() => {
    verifyWebauthnDevice.reset();
    trackError.reset();
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
          <lg-submit-button>
            <button class="webauthn-verify-button__button">
              Authenticate
            </button>
          </lg-submit-button>
          <input type="hidden" name="credential_id" value="">
          <input type="hidden" name="authenticator_data" value="">
          <input type="hidden" name="signature" value="">
          <input type="hidden" name="client_data_json" value="">
          <input type="hidden" name="webauthn_error" value="">
          <input type="hidden" name="screen_lock_error" value="">
        </lg-webauthn-verify-button>
      </form>
    `;
    const element = document.querySelector('lg-webauthn-verify-button')!;
    Object.assign(element.dataset, { credentials: '[]', userChallenge: '[]' }, data);
    const form = document.querySelector('form')!;
    sinon.stub(form, 'submit');
    return { form, element };
  }

  it('assigns button type to avoid default form submission', () => {
    createElement();

    const button = screen.getByRole('button') as HTMLButtonElement;

    expect(button.type).to.equal('button');
  });

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

  it('calls to verify at most one time', async () => {
    createElement();

    const button = screen.getByRole('button', { name: 'Authenticate' });
    await userEvent.click(button);
    await userEvent.click(button);

    expect(verifyWebauthnDevice).to.have.been.calledOnce();
  });

  it('submits with error name as input on thrown expected error', async () => {
    const { form } = createElement();

    verifyWebauthnDevice.throws(new DOMException('', 'NotAllowedError'));

    const button = screen.getByRole('button', { name: 'Authenticate' });
    await userEvent.click(button);
    await expect(form.submit).to.eventually.be.called();

    expect(Object.fromEntries(new window.FormData(form))).to.deep.equal({
      credential_id: '',
      authenticator_data: '',
      client_data_json: '',
      signature: '',
      webauthn_error: 'NotAllowedError',
      screen_lock_error: '',
    });
    expect(trackError).not.to.have.been.called();
  });

  it('submits with error name as input and logs on thrown unexpected error', async () => {
    const { form } = createElement();

    class CustomError extends Error {
      name = 'CustomError';
    }
    const error = new CustomError();
    verifyWebauthnDevice.throws(error);

    const button = screen.getByRole('button', { name: 'Authenticate' });
    await userEvent.click(button);
    await expect(form.submit).to.eventually.be.called();

    expect(Object.fromEntries(new window.FormData(form))).to.deep.equal({
      credential_id: '',
      authenticator_data: '',
      client_data_json: '',
      signature: '',
      webauthn_error: 'CustomError',
      screen_lock_error: '',
    });
    expect(trackError).to.have.been.calledWith(error);
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

    expect(Object.fromEntries(new window.FormData(form))).to.deep.equal({
      credential_id: '123',
      authenticator_data: 'auth',
      client_data_json: 'json',
      signature: 'sig',
      webauthn_error: '',
      screen_lock_error: '',
    });
  });

  it('submits with NotSupportedError resulting from userVerification requirement', async () => {
    const { form } = createElement();

    verifyWebauthnDevice.throws(new DOMException(SCREEN_LOCK_ERROR, 'NotSupportedError'));

    const button = screen.getByRole('button', { name: 'Authenticate' });
    await userEvent.click(button);
    await expect(form.submit).to.eventually.be.called();

    expect(Object.fromEntries(new window.FormData(form))).to.deep.equal({
      credential_id: '',
      authenticator_data: '',
      client_data_json: '',
      signature: '',
      webauthn_error: 'NotSupportedError',
      screen_lock_error: 'true',
    });
    expect(trackError).not.to.have.been.called();
  });
});
