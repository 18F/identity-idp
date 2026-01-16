import sinon from 'sinon';
import quibble from 'quibble';
import { waitFor } from '@testing-library/dom';
import type { IsWebauthnPlatformAvailable } from './is-webauthn-platform-authenticator-available';

describe('WebauthnInputElement', () => {
  const isWebauthnPlatformAvailable = sinon.stub<
    Parameters<IsWebauthnPlatformAvailable>,
    ReturnType<IsWebauthnPlatformAvailable>
  >();

  before(async () => {
    quibble('./is-webauthn-platform-authenticator-available', isWebauthnPlatformAvailable);
    await import('./webauthn-input-element');
  });

  after(() => {
    quibble.reset();
  });

  context('device does not support passkey', () => {
    context('unsupported passkey not shown', () => {
      beforeEach(() => {
        isWebauthnPlatformAvailable.resolves(false);
        document.body.innerHTML = `<lg-webauthn-input hidden></lg-webauthn-input>`;
      });

      it('stays hidden', () => {
        const element = document.querySelector('lg-webauthn-input')!;

        expect(element.hidden).to.be.true();
      });
    });
  });

  context('device supports passkey', () => {
    context('unsupported publickeycredential not shown', () => {
      beforeEach(() => {
        isWebauthnPlatformAvailable.resolves(false);
        document.body.innerHTML = `<lg-webauthn-input hidden></lg-webauthn-input>`;
      });

      it('stays hidden', () => {
        const element = document.querySelector('lg-webauthn-input')!;

        expect(element.hidden).to.be.true();
      });
    });

    context('publickeycredential input is shown', () => {
      beforeEach(() => {
        isWebauthnPlatformAvailable.resolves(true);
        document.body.innerHTML = `<lg-webauthn-input hidden></lg-webauthn-input>`;
      });

      it('becomes visible', async () => {
        const element = document.querySelector('lg-webauthn-input')!;

        await waitFor(() => expect(element.hidden).to.be.false());
      });
    });
  });
});
