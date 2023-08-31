import sinon from 'sinon';
import quibble from 'quibble';
import type { IsWebauthnSupported } from './is-webauthn-supported';
import type { IsWebauthnPasskeySupported } from './is-webauthn-passkey-supported';

describe('WebauthnInputElement', () => {
  const isWebauthnSupported = sinon.stub<
    Parameters<IsWebauthnSupported>,
    ReturnType<IsWebauthnSupported>
  >();
  const isWebauthnPasskeySupported = sinon.stub<
    Parameters<IsWebauthnPasskeySupported>,
    ReturnType<IsWebauthnPasskeySupported>
  >();

  before(async () => {
    quibble('./is-webauthn-supported', isWebauthnSupported);
    quibble('./is-webauthn-passkey-supported', isWebauthnPasskeySupported);
    await import('./webauthn-input-element');
  });

  beforeEach(() => {
    isWebauthnSupported.reset();
    isWebauthnSupported.returns(false);
    isWebauthnPasskeySupported.reset();
    isWebauthnPasskeySupported.returns(false);
  });

  after(() => {
    quibble.reset();
  });

  context('browser does not support webauthn', () => {
    beforeEach(() => {
      isWebauthnSupported.returns(false);
      document.body.innerHTML = `<lg-webauthn-input hidden></lg-webauthn-input>`;
    });

    it('stays hidden', () => {
      const element = document.querySelector('lg-webauthn-input')!;

      expect(element.hidden).to.be.true();
    });
  });

  context('browser supports webauthn', () => {
    beforeEach(() => {
      isWebauthnSupported.returns(true);
    });

    context('input for non-platform authenticator', () => {
      beforeEach(() => {
        document.body.innerHTML = `<lg-webauthn-input hidden></lg-webauthn-input>`;
      });

      it('becomes visible', () => {
        const element = document.querySelector('lg-webauthn-input')!;

        expect(element.hidden).to.be.false();
      });
    });

    context('input for platform authenticator', () => {
      context('no passkey only restriction', () => {
        beforeEach(() => {
          document.body.innerHTML = `<lg-webauthn-input platform hidden></lg-webauthn-input>`;
        });

        it('becomes visible', () => {
          const element = document.querySelector('lg-webauthn-input')!;

          expect(element.hidden).to.be.false();
        });
      });

      context('passkey supported only', () => {
        context('device does not support passkey', () => {
          beforeEach(() => {
            isWebauthnPasskeySupported.returns(false);
            document.body.innerHTML = `<lg-webauthn-input platform passkey-supported-only hidden></lg-webauthn-input>`;
          });

          it('stays hidden', () => {
            const element = document.querySelector('lg-webauthn-input')!;

            expect(element.hidden).to.be.true();
          });
        });

        context('device supports passkey', () => {
          beforeEach(() => {
            isWebauthnPasskeySupported.returns(true);
            document.body.innerHTML = `<lg-webauthn-input platform passkey-supported-only hidden></lg-webauthn-input>`;
          });

          it('becomes visible', () => {
            const element = document.querySelector('lg-webauthn-input')!;

            expect(element.hidden).to.be.false();
          });
        });
      });
    });
  });
});
