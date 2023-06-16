import sinon from 'sinon';
import quibble from 'quibble';
import { waitFor } from '@testing-library/dom';
import type { IsWebauthnSupported } from './is-webauthn-supported';
import type { IsWebauthnPlatformSupported } from './is-webauthn-platform-supported';

describe('WebauthnInputElement', () => {
  const isWebauthnSupported = sinon.stub<
    Parameters<IsWebauthnSupported>,
    ReturnType<IsWebauthnSupported>
  >();
  const isWebauthnPlatformSupported = sinon.stub<
    Parameters<IsWebauthnPlatformSupported>,
    ReturnType<IsWebauthnPlatformSupported>
  >();

  before(async () => {
    quibble('./is-webauthn-supported', isWebauthnSupported);
    quibble('./is-webauthn-platform-supported', isWebauthnPlatformSupported);
    await import('./webauthn-input-element');
  });

  beforeEach(() => {
    isWebauthnSupported.reset();
    isWebauthnSupported.returns(false);
    isWebauthnPlatformSupported.reset();
    isWebauthnPlatformSupported.resolves(false);
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
      context('device does not have available platform authenticator', () => {
        let resolveIsWebauthnPlatformSupported;

        beforeEach(() => {
          isWebauthnPlatformSupported.callsFake(() => {
            resolveIsWebauthnPlatformSupported = new Promise((resolve) => {
              resolve(false);
            });
            return resolveIsWebauthnPlatformSupported;
          });
          document.body.innerHTML = `<lg-webauthn-input platform hidden></lg-webauthn-input>`;
        });

        it('stays hidden', async () => {
          await expect(resolveIsWebauthnPlatformSupported).to.eventually.equal(false);

          const element = document.querySelector('lg-webauthn-input')!;

          expect(element.hidden).to.be.true();
        });
      });

      context('device has available platform authenticator', () => {
        beforeEach(() => {
          isWebauthnPlatformSupported.resolves(true);
          document.body.innerHTML = `<lg-webauthn-input platform hidden></lg-webauthn-input>`;
        });

        it('becomes visible', async () => {
          const element = document.querySelector('lg-webauthn-input')!;

          await waitFor(() => expect(element.hidden).to.be.false());
        });
      });
    });
  });
});
