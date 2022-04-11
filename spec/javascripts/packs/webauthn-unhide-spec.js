import { screen } from '@testing-library/dom';
import { useDefineProperty } from '@18f/identity-test-helpers';
import { useSandbox } from '../support/sinon';
import { unhideWebauthn } from '../../../app/javascript/packs/webauthn-unhide';

describe('webauthn-unhide', () => {
  const sandbox = useSandbox();
  const defineProperty = useDefineProperty();

  const enableWebauthn = () =>
    defineProperty(navigator, 'credentials', {
      configurable: true,
      value: { create: sandbox.spy() },
    });

  const enablePlatformAuthenticator = () => {
    defineProperty(window, 'PublicKeyCredential', {
      configurable: true,
      value: { isUserVerifyingPlatformAuthenticatorAvailable: sandbox.stub().resolves(true) },
    });
  };

  beforeEach(() => {
    document.body.innerHTML = `
      <div id="select_webauthn">
        <input type="radio" name="two_factor_options_form[selection]" value="webauthn" aria-label="Security Key">
      </div>
      <div id="select_webauthn_platform">
        <input type="radio" name="two_factor_options_form[selection]" value="webauthn_platform" aria-label="Face or Touch Unlock">
      </div>
      <div id="select_sms">
        <input type="radio" name="two_factor_options_form[selection]" value="sms" aria-label="Text message">
      </div>
      <div id="select_voice">
        <input type="radio" name="two_factor_options_form[selection]" value="voice" aria-label="Automated phone call">
      </div>
      <div id="select_auth_app">
        <input type="radio" name="two_factor_options_form[selection]" value="auth_app" aria-label="Authentication app">
      </div>
    `;
  });

  context('without support for webauthn', () => {
    it('hides webauthn option', async () => {
      await unhideWebauthn();

      const input = screen.getByLabelText('Security Key');

      expect(input.closest('.display-none')).to.exist();
    });
  });

  context('with support for webauthn', () => {
    before(enableWebauthn);

    it('keeps webauthn option visible', async () => {
      await unhideWebauthn();

      const input = screen.getByLabelText('Security Key');

      expect(input.closest('.display-none')).to.not.exist();
    });
  });

  context('without support for webauthn platform authentication', () => {
    it('hides webauthn option', async () => {
      await unhideWebauthn();

      const input = screen.getByLabelText('Face or Touch Unlock');

      expect(input.closest('.display-none')).to.exist();
    });
  });

  context('with support for webauthn platform authentication', () => {
    before(enablePlatformAuthenticator);

    it('keeps webauthn option visible', async () => {
      await unhideWebauthn();

      const input = screen.getByLabelText('Face or Touch Unlock');

      expect(input.closest('.display-none')).to.not.exist();
    });
  });

  context('with default checked item', () => {
    it('maintains checked item if not webauthn', async () => {
      const textMessageInput = screen.getByLabelText('Text message');
      textMessageInput.checked = true;

      await unhideWebauthn();

      expect(textMessageInput.checked).to.be.true();
    });

    it('maintains checked item if webauthn and supported', async () => {
      const securityKeyInput = screen.getByLabelText('Security Key');
      securityKeyInput.checked = true;

      enableWebauthn();
      await unhideWebauthn();

      expect(securityKeyInput.checked).to.be.true();
    });

    it('switches checked item to next supported webauthn option', async () => {
      const securityKeyInput = screen.getByLabelText('Security Key');
      securityKeyInput.checked = true;

      enablePlatformAuthenticator();
      await unhideWebauthn();

      const platformAuthenticatorInput = screen.getByLabelText('Face or Touch Unlock');
      expect(platformAuthenticatorInput.checked).to.be.true();
    });

    it('switches checked item to next supported non-webauthn option', async () => {
      const securityKeyInput = screen.getByLabelText('Security Key');
      securityKeyInput.checked = true;

      await unhideWebauthn();

      const textMessageInput = screen.getByLabelText('Text message');
      expect(textMessageInput.checked).to.be.true();
    });

    it('does nothing if there are no other options to switch to', async () => {
      const securityKeyInput = screen.getByLabelText('Security Key');
      securityKeyInput.checked = true;

      screen.getAllByRole('radio').forEach((input) => {
        if (input !== securityKeyInput) {
          input.parentNode.removeChild(input);
        }
      });

      await unhideWebauthn();

      expect(securityKeyInput.checked).to.be.true();
    });
  });
});
