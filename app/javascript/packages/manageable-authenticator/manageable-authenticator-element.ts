import { request } from '@18f/identity-request';
import { forceSubmit } from '@18f/identity-url';
import type { SpinnerButtonElement } from '@18f/identity-spinner-button/spinner-button-element';

interface ErrorResponse {
  error: string;
}

interface Strings {
  renamed: string;

  deleteConfirm: string;

  deleted: string;
}

class ManageableAuthenticatorElement extends HTMLElement {
  connectedCallback() {
    this.manageButton.addEventListener('click', () => this.#handleManageClick());
    this.doneButton.addEventListener('click', () => this.toggleEditing(false));
    this.renameButton.addEventListener('click', () => this.toggleRenaming(true));
    this.deleteButton.addEventListener('click', () => this.delete());
    this.cancelRenameButton.addEventListener('click', () => this.toggleRenaming(false));
    this.renameForm.addEventListener('submit', (event) => this.#handleRenameSubmit(event));
    this.addEventListener('keydown', (event) => this.#handleKeyDown(event));

    this.#editIfSelectedFromReauthentication();
  }

  get strings(): Strings {
    return JSON.parse(this.querySelector('.manageable-authenticator__strings')!.textContent!);
  }

  get manageButton(): HTMLButtonElement {
    return this.querySelector<HTMLButtonElement>('.manageable-authenticator__manage-button')!;
  }

  get doneButton(): HTMLButtonElement {
    return this.querySelector<HTMLButtonElement>('.manageable-authenticator__done-button')!;
  }

  get editContainer(): HTMLElement {
    return this.querySelector<HTMLElement>('.manageable-authenticator__edit')!;
  }

  get renameButton(): HTMLButtonElement {
    return this.querySelector<HTMLButtonElement>('.manageable-authenticator__rename-button')!;
  }

  get deleteButton(): SpinnerButtonElement {
    return this.querySelector<SpinnerButtonElement>('.manageable-authenticator__delete-button')!;
  }

  get renameInput(): HTMLInputElement {
    return this.querySelector<HTMLInputElement>('.manageable-authenticator__rename-input')!;
  }

  get renameForm(): HTMLFormElement {
    return this.querySelector<HTMLFormElement>('.manageable-authenticator__rename')!;
  }

  get saveRenameButton(): SpinnerButtonElement {
    return this.querySelector<SpinnerButtonElement>(
      '.manageable-authenticator__save-rename-button',
    )!;
  }

  get cancelRenameButton(): HTMLButtonElement {
    return this.querySelector<HTMLButtonElement>(
      '.manageable-authenticator__cancel-rename-button',
    )!;
  }

  get alert(): HTMLElement {
    return this.querySelector<HTMLElement>('.manageable-authenticator__alert')!;
  }

  get uniqueId(): string {
    return this.getAttribute('unique-id')!;
  }

  get apiURL(): string {
    return this.getAttribute('api-url')!;
  }

  get reauthenticationURL(): string {
    return this.getAttribute('reauthentication-url')!;
  }

  get reauthenticateAt(): Date {
    return new Date(this.getAttribute('reauthenticate-at')!);
  }

  get name(): string {
    return this.getAttribute('configuration-name')!;
  }

  set name(name: string) {
    this.setAttribute('configuration-name', name);

    this.querySelectorAll('.manageable-authenticator__name').forEach((nameElement) => {
      nameElement.textContent = name;
    });
  }

  toggleEditing(isEditing: boolean) {
    this.toggleRenaming(false);

    this.classList.toggle('manageable-authenticator--editing', isEditing);

    const focusTarget = isEditing ? this.editContainer : this.manageButton;
    focusTarget.focus();

    this.#setAlertMessage(null);
  }

  toggleRenaming(isRenaming: boolean) {
    this.classList.toggle('manageable-authenticator--renaming', isRenaming);

    this.renameInput.value = this.name;

    const focusTarget = isRenaming ? this.renameInput : this.editContainer;
    focusTarget.focus();

    if (isRenaming) {
      this.renameInput.setSelectionRange(
        this.renameInput.value.length,
        this.renameInput.value.length,
      );
    }

    this.#setAlertMessage(null);
  }

  async delete() {
    // Disable reason: This is an intentional user-facing confirmation prompt.
    /* eslint-disable-next-line no-alert */
    if (!window.confirm(this.strings.deleteConfirm)) {
      this.deleteButton.toggleSpinner(false);
      return;
    }

    await this.#checkForReauthentication();

    const response = await request(this.apiURL, { method: 'DELETE', read: false });
    if (response.ok) {
      this.classList.add('manageable-authenticator--deleted');
      this.#setAlertMessage(this.strings.deleted, { type: 'success' });
      this.alert.focus();
    } else {
      const { error } = (await response.json()) as ErrorResponse;
      this.deleteButton.toggleSpinner(false);
      this.#setAlertMessage(error, { type: 'error' });
    }
  }

  #isReauthenticationRequired() {
    return this.reauthenticateAt < new Date();
  }

  #editIfSelectedFromReauthentication() {
    const url = new URL(window.location.href);
    const selectedAuthenticator = url.searchParams.get('manage_authenticator');

    if (selectedAuthenticator === this.uniqueId) {
      this.toggleEditing(true);
      url.searchParams.delete('manage_authenticator');
      window.history.replaceState(null, '', url.toString());
      this.editContainer.scrollIntoView({ block: 'start', inline: 'nearest', behavior: 'smooth' });
    }
  }

  #setAlertMessage(message: string | null, { type }: { type?: 'error' | 'success' } = {}) {
    this.classList.toggle('manageable-authenticator--alert-visible', !!message);
    if (message) {
      this.alert.classList.toggle('usa-alert--error', type === 'error');
      this.alert.classList.toggle('usa-alert--success', type === 'success');
      this.alert.querySelector('.usa-alert__text')!.textContent = message;
    }
  }

  #handleKeyDown(event: KeyboardEvent) {
    switch (event.key) {
      case 'Escape':
        event.preventDefault();
        this.toggleEditing(false);
        break;

      default:
    }
  }

  async #handleManageClick() {
    await this.#checkForReauthentication();
    this.toggleEditing(true);
  }

  async #handleRenameSubmit(event: SubmitEvent) {
    event.preventDefault();
    await this.#checkForReauthentication();
    const name = this.renameInput.value;
    const response = await request(this.apiURL, {
      method: 'PUT',
      json: { name },
      read: false,
    });

    this.saveRenameButton.toggleSpinner(false);

    if (response.ok) {
      this.name = name;
      this.toggleRenaming(false);
      this.editContainer.focus();
      this.#setAlertMessage(this.strings.renamed, { type: 'success' });
    } else {
      const { error } = (await response.json()) as ErrorResponse;
      this.#setAlertMessage(error, { type: 'error' });
    }
  }

  #checkForReauthentication(): Promise<void> {
    return new Promise((resolve) => {
      if (this.#isReauthenticationRequired()) {
        forceSubmit(this.reauthenticationURL);
      } else {
        resolve();
      }
    });
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-manageable-authenticator': ManageableAuthenticatorElement;
  }
}

if (!customElements.get('lg-manageable-authenticator')) {
  customElements.define('lg-manageable-authenticator', ManageableAuthenticatorElement);
}

export default ManageableAuthenticatorElement;
