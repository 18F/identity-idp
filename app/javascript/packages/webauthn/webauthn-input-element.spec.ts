import sinon from 'sinon';
import quibble from 'quibble';
import { waitFor } from '@testing-library/dom';
import { useSandbox } from '@18f/identity-test-helpers';
import * as analytics from '@18f/identity-analytics';
import type { IsWebauthnPasskeySupported } from './is-webauthn-passkey-supported';
import type { IsWebauthnPlatformAvailable } from './is-webauthn-platform-authenticator-available';

describe('WebauthnInputElement', () => {
  const isWebauthnPasskeySupported = sinon.stub<
    Parameters<IsWebauthnPasskeySupported>,
    ReturnType<IsWebauthnPasskeySupported>
  >();

  const isWebauthnPlatformAvailable = sinon.stub<
    Parameters<IsWebauthnPlatformAvailable>,
    ReturnType<IsWebauthnPlatformAvailable>
  >();

  before(async () => {
    quibble('./is-webauthn-passkey-supported', isWebauthnPasskeySupported);
    quibble('./is-webauthn-platform-authenticator-available', isWebauthnPlatformAvailable);
    await import('./webauthn-input-element');
  });

  after(() => {
    quibble.reset();
  });

  context('device does not support passkey', () => {
    context('unsupported passkey not shown', () => {
      beforeEach(() => {
        isWebauthnPasskeySupported.returns(false);
        isWebauthnPlatformAvailable.resolves(false);
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
        isWebauthnPlatformAvailable.resolves(false);
        document.body.innerHTML = `<lg-webauthn-input show-unsupported-passkey hidden></lg-webauthn-input>`;
      });

      it('becomes visible, with modifier class', () => {
        const element = document.querySelector('lg-webauthn-input')!;

        expect(element.hidden).to.be.true();
        expect(element.classList.contains('webauthn-input--unsupported-passkey')).to.be.false();
      });
    });
  });

  context('device supports passkey', () => {
    context('unsupported publickeycredential not shown', () => {
      beforeEach(() => {
        isWebauthnPlatformAvailable.resolves(false);
        isWebauthnPasskeySupported.returns(true);
        document.body.innerHTML = `<lg-webauthn-input hidden></lg-webauthn-input>`;
      });

      it('stays hidden', () => {
        const element = document.querySelector('lg-webauthn-input')!;

        expect(element.hidden).to.be.true();
      });
    });

    context('publickeycredential input is shown', () => {
      beforeEach(() => {
        isWebauthnPasskeySupported.returns(true);
        isWebauthnPlatformAvailable.resolves(true);
        document.body.innerHTML = `<lg-webauthn-input hidden></lg-webauthn-input>`;
      });

      it('becomes visible', async () => {
        const element = document.querySelector('lg-webauthn-input')!;

        await waitFor(() => expect(element.hidden).to.be.false());
      });
    });
  });

  context('Desktop F/T unlock A/B test', () => {
    context('desktop F/T unlock setup enabled', () => {
      const sandbox = useSandbox()
      beforeEach(() => {
        isWebauthnPlatformAvailable.resolves(true);
        sandbox.stub(analytics, 'trackEvent');
        document.body.innerHTML = `<lg-webauthn-input desktop-ft-unlock-option></lg-webauthn-input>`;
      });

      it('becomes visible', () => {
        const element = document.querySelector('lg-webauthn-input')!;
        expect(element.hidden).to.be.false();
      });
    });

    context('desktop F/T unlock setup disabled', () => {
      const sandbox = useSandbox()
      beforeEach(() => {
        isWebauthnPlatformAvailable.resolves(true);
        document.body.innerHTML = `<lg-webauthn-input hidden></lg-webauthn-input>`;
        sandbox.stub(analytics, 'trackEvent');
      });

      it('is hidden', () => {
        const element = document.querySelector('lg-webauthn-input')!;
        expect(element.hidden).to.be.true();
      })
    })
  });
});
