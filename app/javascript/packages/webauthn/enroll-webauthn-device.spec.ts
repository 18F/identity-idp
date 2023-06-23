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
  const excludeCredentials = extractCredentials(
    'Y3JlZGVudGlhbDEyMw==,Y3JlZGVudGlhbDQ1Ng=='.split(','),
  ); // Base64-encoded 'credential123,credential456'

  beforeEach(() => {
    defineProperty(navigator, 'credentials', {
      configurable: true,
      value: {
        create: sandbox.stub().resolves({
          rawId: Buffer.from([214, 109]), // encodes to '123'
          id: '123',
          response: {
            // decodes to 'attest'
            attestationObject: Buffer.from([97, 116, 116, 101, 115, 116]),
            // decodes to 'json'
            clientDataJSON: Buffer.from([106, 115, 111, 110]),
          },
        }),
      },
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
          userVerification: 'discouraged',
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
      webauthnId: '1m0=', // Base64.encode64('123'),
      webauthnPublicKey: '123',
      attestationObject: 'YXR0ZXN0', // Base64.encode('attest')
      clientDataJSON: 'anNvbg==', // Base64.encode('json')
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
