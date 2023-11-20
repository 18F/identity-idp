import sinon from 'sinon';
import quibble from 'quibble';
import { useSandbox, useDefineProperty } from '@18f/identity-test-helpers';
import type { IsWebauthnPasskeySupported } from './is-webauthn-passkey-supported';

describe('WebauthnInputElement', () => {
  const isWebauthnPasskeySupported = sinon.stub<
    Parameters<IsWebauthnPasskeySupported>,
    ReturnType<IsWebauthnPasskeySupported>
  >();

  const defineProperty = useDefineProperty();
  const sandbox = useSandbox();

  before(async () => {
    quibble('./is-webauthn-passkey-supported', isWebauthnPasskeySupported);
    await import('./webauthn-input-element');
  });

  after(() => {
    quibble.reset();
  });

  context('device does not support passkey', () => {
    context('unsupported passkey not shown', () => {
      beforeEach(() => {
        defineProperty(window, 'PublicKeyCredential', {
          configurable: true,
          value: {
            isUserVerifyingPlatformAuthenticatorAvailable: sandbox.stub().resolves(true),
          },
        });
        isWebauthnPasskeySupported.returns(false);
        document.body.innerHTML = `<lg-webauthn-input hidden></lg-webauthn-input>`;
      });

      it('stays hidden', () => {
        const element = document.querySelector('lg-webauthn-input')!;

        expect(element.hidden).to.be.true();
      });
    });

    context('unsupported passkey shown', () => {
      beforeEach(() => {
        isWebauthnPasskeySupported.returns(false);
        document.body.innerHTML = `<lg-webauthn-input show-unsupported-passkey hidden></lg-webauthn-input>`;
      });

      it('becomes visible, with modifier class', () => {
        const element = document.querySelector('lg-webauthn-input')!;

        expect(element.hidden).to.be.false();
        expect(element.classList.contains('webauthn-input--unsupported-passkey')).to.be.true();
      });
    });
  });

  context('device supports passkey', () => {
    context('unsupported publickeycredential not shown', () => {
      beforeEach(() => {
        defineProperty(window, 'PublicKeyCredential', {
          configurable: true,
          value: undefined,
        });

        isWebauthnPasskeySupported.returns(true);
        document.body.innerHTML = `<lg-webauthn-input hidden></lg-webauthn-input>`;
      });

      it('becomes visible', () => {
        const element = document.querySelector('lg-webauthn-input')!;

        expect(element.hidden).to.be.true();
      });
    });

    context('publickeycredential input is shown', () => {
      beforeEach(() => {
        defineProperty(window, 'PublicKeyCredential', {
          configurable: true,
          value: {
            isUserVerifyingPlatformAuthenticatorAvailable: sandbox.stub().resolves(true),
          },
        });

        isWebauthnPasskeySupported.returns(true);
        document.body.innerHTML = `<lg-webauthn-input hidden></lg-webauthn-input>`;
      });

      it('becomes visible', () => {
        const element = document.querySelector('lg-webauthn-input')!;

        expect(element.hidden).to.be.false();
      });
    });
  });
});
