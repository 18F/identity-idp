import { TextEncoder } from 'util';
import { useSandbox } from '@18f/identity-test-helpers';
import * as WebAuthn from '../../../app/javascript/app/webauthn';

describe('WebAuthn', () => {
  const sandbox = useSandbox();

  let originalNavigator;
  let originalCredentials;
  beforeEach(() => {
    originalNavigator = global.navigator;
    originalCredentials = global.navigator.credentials;
    global.navigator.credentials = {
      create: () => {},
      get: () => {},
    };
  });

  afterEach(() => {
    global.navigator = originalNavigator;
    global.navigator.credentials = originalCredentials;
  });

  describe('isWebAuthnEnabled', () => {
    it('returns true if webauthn is enabled', () => {
      expect(WebAuthn.isWebAuthnEnabled()).to.equal(true);
    });

    it('returns false if webauthn is disabled', () => {
      global.navigator.credentials = undefined;
      expect(WebAuthn.isWebAuthnEnabled()).to.equal(false);
      global.navigator = undefined;
      expect(WebAuthn.isWebAuthnEnabled()).to.equal(false);
    });
  });

  describe('extractCredentials', () => {
    it('returns [] if credentials are empty string', () => {
      expect(WebAuthn.extractCredentials('')).to.eql([]);
    });
  });

  describe('enrollWebauthnDevice', () => {
    const userId = '123';
    const userEmail = 'test@test.com';
    const userChallenge = '[1, 2, 3, 4, 5, 6, 7, 8]';
    const excludeCredentials = 'Y3JlZGVudGlhbDEyMw==,Y3JlZGVudGlhbDQ1Ng=='; // Base64-encoded 'credential123,credential456'

    const createReturnValue = {
      rawId: Buffer.from([214, 109]), // encodes to '123'
      id: '123',
      response: {
        // decodes to 'attest'
        attestationObject: Buffer.from([97, 116, 116, 101, 115, 116]),
        // decodes to 'json'
        clientDataJSON: Buffer.from([106, 115, 111, 110]),
      },
    };

    it('enrolls a device using the proper create options', (done) => {
      const expectedCreateOptions = {
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
          excludeList: [],
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
      };

      const expectedReturnValue = {
        webauthnId: '1m0=', // Base64.encode64('123'),
        webauthnPublicKey: '123',
        attestationObject: 'YXR0ZXN0', // Base64.encode('attest')
        clientDataJSON: 'anNvbg==', // Base64.encode('json')
      };

      let createCalled = false;
      navigator.credentials.create = (createOptions) => {
        createCalled = true;
        expect(createOptions).to.deep.equal(expectedCreateOptions);
        return Promise.resolve(createReturnValue);
      };

      WebAuthn.enrollWebauthnDevice({
        userId,
        userEmail,
        userChallenge,
        excludeCredentials,
        platformAuthenticator: false,
      })
        .then((result) => {
          expect(createCalled).to.eq(true);
          expect(result).to.deep.equal(expectedReturnValue);
        })
        .then(() => done())
        .catch(done);
    });

    it('forwards errors from the webauthn api', (done) => {
      const dummyError = new Error('dummy error');
      navigator.credentials.create = () => Promise.reject(dummyError);

      WebAuthn.enrollWebauthnDevice({
        userId,
        userEmail,
        userChallenge,
        excludeCredentials,
      })
        .catch((error) => {
          expect(error).to.equal(dummyError);
          done();
        })
        .catch(done);
    });

    context('platform authenticator', () => {
      it('enrolls a device with correct authenticatorAttachment', async () => {
        sandbox.stub(navigator.credentials, 'create').resolves(createReturnValue);

        await WebAuthn.enrollWebauthnDevice({
          userId,
          userEmail,
          userChallenge,
          excludeCredentials,
          platformAuthenticator: true,
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

  describe('verifyWebauthnDevice', () => {
    const userChallenge = '[1, 2, 3, 4, 5, 6, 7, 8]';
    const credentialIds = 'Y3JlZGVudGlhbDEyMw==,Y3JlZGVudGlhbDQ1Ng=='; // Base64-encoded 'credential123,credential456'

    it('enrolls a device using the proper get options', (done) => {
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

      const getReturnValue = {
        rawId: Buffer.from([214, 109]), // encodes to '123'
        response: {
          authenticatorData: Buffer.from([97, 117, 116, 104]), // decodes to 'auth'
          clientDataJSON: Buffer.from([106, 115, 111, 110]), // decodes to 'json'
          signature: Buffer.from([115, 105, 103]), // decodes to 'sig'
        },
      };

      const expectedReturnValue = {
        credentialId: '1m0=', // Base64.encode64('123')
        authenticatorData: 'YXV0aA==', // Base64.encode64('auth')
        clientDataJSON: 'anNvbg==', // Base64.encode64('json')
        signature: 'c2ln', // Base64.encode64('sig')
      };

      let getCalled = false;
      navigator.credentials.get = (getOptions) => {
        getCalled = true;
        expect(getOptions).to.deep.equal(expectedGetOptions);
        return Promise.resolve(getReturnValue);
      };

      WebAuthn.verifyWebauthnDevice({
        userChallenge,
        credentialIds,
      })
        .then((result) => {
          expect(getCalled).to.eq(true);
          expect(result).to.deep.equal(expectedReturnValue);
        })
        .then(() => done())
        .catch(done);
    });

    it('forwards errors from the webauthn api', (done) => {
      const dummyError = new Error('dummy error');
      navigator.credentials.get = () => Promise.reject(dummyError);

      WebAuthn.verifyWebauthnDevice({
        userChallenge,
        credentialIds,
      })
        .catch((error) => {
          expect(error).to.equal(dummyError);
          done();
        })
        .catch(done);
    });
  });
});
