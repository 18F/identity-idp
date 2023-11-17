import { useSandbox, useDefineProperty } from '@18f/identity-test-helpers';
import enrollWebauthnDevice from './enroll-webauthn-device';
import extractCredentials from './extract-credentials';
import { longToByteArray } from './converters';

describe('enrollWebauthnDevice', () => {
  const sandbox = useSandbox();
  const defineProperty = useDefineProperty();
  const user = {
    id: longToByteArray(123),
    displayName: 'test@test.com',
    name: 'test@test.com',
  };
  const challenge = new Uint8Array(JSON.parse('[1, 2, 3, 4, 5, 6, 7, 8]'));
  const excludeCredentials = extractCredentials([btoa('credential123'), btoa('credential456')]);
  const authenticatorData = Uint8Array.from([
    73, 150, 13, 229, 136, 14, 140, 104, 116, 52, 23, 15, 100, 118, 96, 91, 143, 228, 174, 185, 162,
    134, 50, 199, 153, 92, 243, 186, 131, 29, 151, 99, 65, 0, 0, 0, 0, 173, 206, 0, 2, 53, 188, 198,
    10, 100, 139, 11, 37, 241, 240, 85, 3, 0, 32, 169, 49, 66, 252, 224, 54, 15, 214, 228, 6, 10,
    85, 78, 208, 77, 34, 39, 214, 145, 170, 65, 32, 238, 254, 195, 95, 57, 111, 190, 230, 120, 66,
    165, 1, 2, 3, 38, 32, 1, 33, 88, 32, 190, 188, 238, 23, 175, 12, 47, 114, 213, 20, 157, 44, 97,
    235, 85, 193, 177, 166, 8, 167, 4, 70, 56, 13, 28, 128, 215, 115, 131, 35, 104, 80, 34, 88, 32,
    246, 201, 51, 10, 198, 109, 109, 163, 114, 35, 161, 239, 168, 132, 109, 247, 224, 48, 188, 131,
    225, 190, 13, 223, 243, 75, 174, 252, 212, 215, 183, 9,
  ]).buffer;

  function defineNavigatorCredentials({
    getAuthenticatorData,
    getTransports,
  }: {
    getAuthenticatorData?: AuthenticatorAttestationResponse['getAuthenticatorData'];
    getTransports?: AuthenticatorAttestationResponse['getTransports'];
  }) {
    defineProperty(navigator, 'credentials', {
      configurable: true,
      value: {
        create: sandbox.stub().resolves({
          rawId: Buffer.from('123', 'utf-8'),
          id: '123',
          response: {
            attestationObject: Buffer.from('attest', 'utf-8'),
            clientDataJSON: Buffer.from('json', 'utf-8'),
            getAuthenticatorData,
            getTransports,
          },
        }),
      },
    });
  }

  context('fully supported AuthenticatorAttestationResponse', () => {
    beforeEach(() => {
      defineNavigatorCredentials({
        getAuthenticatorData: () => authenticatorData,
        getTransports: () => ['usb'],
      });
    });

    it('enrolls a device using the proper create options', async () => {
      const result = await enrollWebauthnDevice({
        user,
        challenge,
        excludeCredentials,
        authenticatorAttachment: 'cross-platform',
      });

      expect(navigator.credentials.create).to.have.been.calledWith({
        publicKey: {
          challenge: new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]),
          rp: { name: 'example.test' },
          user: {
            id: new Uint8Array([123, 0, 0, 0, 0, 0, 0, 0]),
            name: 'test@test.com',
            displayName: 'test@test.com',
          },
          pubKeyCredParams: [
            { type: 'public-key', alg: -7 },
            { type: 'public-key', alg: -35 },
            { type: 'public-key', alg: -36 },
            { type: 'public-key', alg: -37 },
            { type: 'public-key', alg: -38 },
            { type: 'public-key', alg: -39 },
            { type: 'public-key', alg: -257 },
          ],
          timeout: 800000,
          attestation: 'none',
          authenticatorSelection: {
            authenticatorAttachment: 'cross-platform',
          },
          excludeCredentials: [
            {
              id: new TextEncoder().encode('credential123').buffer,
              type: 'public-key',
            },
            {
              id: new TextEncoder().encode('credential456').buffer,
              type: 'public-key',
            },
          ],
        },
      });

      expect(result).to.deep.equal({
        webauthnId: btoa('123'),
        attestationObject: btoa('attest'),
        clientDataJSON: btoa('json'),
        authenticatorDataFlagsValue: 65,
        transports: ['usb'],
      });
    });

    it('forwards errors from the webauthn api', async () => {
      const dummyError = new Error('dummy error');
      navigator.credentials.create = () => Promise.reject(dummyError);

      let didCatch;
      try {
        await enrollWebauthnDevice({ user, challenge, excludeCredentials });
      } catch (error) {
        expect(error).to.equal(dummyError);
        didCatch = true;
      }

      expect(didCatch).to.be.true();
    });

    context('platform authenticator', () => {
      it('enrolls a device with correct authenticatorAttachment', async () => {
        await enrollWebauthnDevice({
          user,
          challenge,
          excludeCredentials,
          authenticatorAttachment: 'platform',
        });

        expect(navigator.credentials.create).to.have.been.calledWithMatch({
          publicKey: {
            authenticatorSelection: {
              authenticatorAttachment: 'platform',
            },
          },
        });
      });
    });
  });

  context('AuthenticatorAttestationResponse#getTransports unsupported', () => {
    beforeEach(() => {
      defineNavigatorCredentials({
        getAuthenticatorData: () => authenticatorData,
        getTransports: undefined,
      });
    });

    it('enrolls a device with a blank transports result', async () => {
      const result = await enrollWebauthnDevice({
        user,
        challenge,
        excludeCredentials,
        authenticatorAttachment: 'cross-platform',
      });

      expect(result.transports).to.equal(undefined);
    });
  });

  context('AuthenticatorAttestationResponse#getAuthenticatorData unsupported', () => {
    beforeEach(() => {
      defineNavigatorCredentials({
        getAuthenticatorData: undefined,
        getTransports: () => ['usb'],
      });
    });

    it('enrolls a device with a blank authenticatorDataFlagsValue result', async () => {
      const result = await enrollWebauthnDevice({
        user,
        challenge,
        excludeCredentials,
        authenticatorAttachment: 'cross-platform',
      });

      expect(result.authenticatorDataFlagsValue).to.equal(undefined);
    });
  });
});
