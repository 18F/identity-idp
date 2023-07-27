import sinon from 'sinon';
import quibble from 'quibble';
import type { IsWebauthnPasskeySupported } from './is-webauthn-passkey-supported';

describe('WebauthnInputElement', () => {
  const isWebauthnPasskeySupported = sinon.stub<
    Parameters<IsWebauthnPasskeySupported>,
    ReturnType<IsWebauthnPasskeySupported>
  >();

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
    beforeEach(() => {
      isWebauthnPasskeySupported.returns(true);
      document.body.innerHTML = `<lg-webauthn-input hidden></lg-webauthn-input>`;
    });

    it('becomes visible', () => {
      const element = document.querySelector('lg-webauthn-input')!;

      expect(element.hidden).to.be.false();
    });
  });
});
