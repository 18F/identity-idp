import { trackError } from '@18f/identity-analytics';
import type SubmitButtonElement from '@18f/identity-submit-button/submit-button-element';
import verifyWebauthnDevice from './verify-webauthn-device';
import isExpectedWebauthnError from './is-expected-error';
import isUserVerificationScreenLockError from './is-user-verification-screen-lock-error';
import type { VerifyCredentialDescriptor } from './verify-webauthn-device';

export interface WebauthnVerifyButtonDataset extends DOMStringMap {
  credentials: string;
  userChallenge: string;
}

class WebauthnVerifyButtonElement extends HTMLElement {
  dataset: WebauthnVerifyButtonDataset;

  connectedCallback() {
    this.button.addEventListener('click', () => this.verify(), { once: true });
  }

  get form(): HTMLFormElement {
    return this.closest('form')!;
  }

  get button(): HTMLButtonElement {
    return this.querySelector('.webauthn-verify-button__button')!;
  }

  get submitButton(): SubmitButtonElement {
    return this.querySelector('lg-submit-button')!;
  }

  get spinner(): HTMLElement {
    return this.querySelector('.webauthn-verify-button__spinner')!;
  }

  get credentials(): VerifyCredentialDescriptor[] {
    return JSON.parse(this.dataset.credentials);
  }

  get userChallenge(): string {
    return this.dataset.userChallenge;
  }

  async verify() {
    this.spinner.hidden = false;

    const { userChallenge, credentials } = this;

    try {
      const result = await verifyWebauthnDevice({ userChallenge, credentials });
      this.setInputValue('credential_id', result.credentialId);
      this.setInputValue('authenticator_data', result.authenticatorData);
      this.setInputValue('client_data_json', result.clientDataJSON);
      this.setInputValue('signature', result.signature);
    } catch (error) {
      if (!isExpectedWebauthnError(error, { isVerifying: true })) {
        trackError(error, { errorId: 'webauthnVerify' });
      }

      if (isUserVerificationScreenLockError(error)) {
        this.setInputValue('screen_lock_error', 'true');
      }

      this.setInputValue('webauthn_error', error.name);
    }

    this.form.submit();
  }

  setInputValue(name: string, value: string) {
    const input = this.querySelector<HTMLInputElement>(`[name="${name}"]`)!;
    input.value = value;
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-webauthn-verify-button': WebauthnVerifyButtonElement;
  }
}

if (!customElements.get('lg-webauthn-verify-button')) {
  customElements.define('lg-webauthn-verify-button', WebauthnVerifyButtonElement);
}

export default WebauthnVerifyButtonElement;
