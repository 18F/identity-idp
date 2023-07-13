import verifyWebauthnDevice from './verify-webauthn-device';
import type { VerifyCredentialDescriptor } from './verify-webauthn-device';

export interface WebauthnVerifyButtonDataset extends DOMStringMap {
  credentials: string;
  userChallenge: string;
}

class WebauthnVerifyButtonElement extends HTMLElement {
  dataset: WebauthnVerifyButtonDataset;

  connectedCallback() {
    this.setButtonAttributes();
    this.bindEvents();
  }

  get button(): HTMLButtonElement {
    return this.querySelector('.webauthn-verify-button__button')!;
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

  setButtonAttributes() {
    this.button.type = 'button';
  }

  bindEvents() {
    this.button.addEventListener('click', () => this.verify());
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
      this.setInputValue('webauthn_error', error.name);
    }

    this.closest('form')?.submit();
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
