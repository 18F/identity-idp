import { TextEncoder } from 'util';
import { useSandbox, useDefineProperty } from '@18f/identity-test-helpers';
import verifyWebauthnDevice from './verify-webauthn-device';

describe('verifyWebauthnDevice', () => {
  const sandbox = useSandbox();
  const defineProperty = useDefineProperty();

  const userChallenge = '[1, 2, 3, 4, 5, 6, 7, 8]';
  const credentialIds = [btoa('credential123'), btoa('credential456')].join(',');

  context('webauthn api resolves credential', () => {
    beforeEach(() => {
      defineProperty(navigator, 'credentials', {
        configurable: true,
        value: {
          get: sandbox.stub().resolves({
            rawId: Buffer.from('123', 'utf-8'),
            response: {
              authenticatorData: Buffer.from('auth', 'utf-8'),
              clientDataJSON: Buffer.from('json', 'utf-8'),
              signature: Buffer.from('sig', 'utf-8'),
            },
          }),
        },
      });
    });

    it('resolves to credential', async () => {
      const expectedGetOptions = {
        publicKey: {
          challenge: new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]),
          rpId: 'example.test',
          allowCredentials: [
            {
              id: new TextEncoder().encode('credential123').buffer,
              type: 'public-key',
            },
            {
              id: new TextEncoder().encode('credential456').buffer,
              type: 'public-key',
            },
          ],
          timeout: 800000,
        },
      };

      const result = await verifyWebauthnDevice({
        userChallenge,
        credentialIds,
      });

      expect(navigator.credentials.get).to.have.been.calledWith(expectedGetOptions);
      expect(result).to.deep.equal({
        credentialId: btoa('123'),
        authenticatorData: btoa('auth'),
        clientDataJSON: btoa('json'),
        signature: btoa('sig'),
      });
    });
  });

  context('webauthn rejects with an error', () => {
    const authError = new Error();

    beforeEach(() => {
      defineProperty(navigator, 'credentials', {
        configurable: true,
        value: {
          get: sandbox.stub().rejects(authError),
        },
      });
    });

    it('forwards errors', async () => {
      let didCatch;
      try {
        await verifyWebauthnDevice({
          userChallenge,
          credentialIds,
        });
      } catch (error) {
        expect(error).to.equal(error);
        didCatch = true;
      }

      expect(didCatch).to.be.true();
    });
  });
});
