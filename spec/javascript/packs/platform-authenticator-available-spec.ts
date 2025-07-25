import quibble from 'quibble';

describe('platform-authenticator-available', () => {
  let initialize: () => void;
  let isWebauthnPlatformAuthenticatorAvailable;

  before(async () => {
    quibble('@18f/identity-webauthn', {
      isWebauthnPlatformAuthenticatorAvailable: () =>
        Promise.resolve(isWebauthnPlatformAuthenticatorAvailable),
    });

    ({ initialize } = await import(
      '../../../app/javascript/packs/platform-authenticator-available'
    ));
  });

  beforeEach(() => {
    document.body.innerHTML = '<input id="platform_authenticator_available">';
  });

  after(() => {
    quibble.reset();
  });

  const getInput = (): HTMLInputElement =>
    document.getElementById('platform_authenticator_available') as HTMLInputElement;

  context('passkey supported', () => {
    context('platform authenticator available', () => {
      beforeEach(() => {
        isWebauthnPlatformAuthenticatorAvailable = true;
      });

      it('sets the input value to true', async () => {
        await initialize();

        expect(getInput().value).to.equal('true');
      });
    });

    context('platform authenticator not available', () => {
      beforeEach(() => {
        isWebauthnPlatformAuthenticatorAvailable = false;
      });

      it('leaves the input value blank', async () => {
        await initialize();

        expect(getInput().value).to.be.empty();
      });
    });
  });
});
