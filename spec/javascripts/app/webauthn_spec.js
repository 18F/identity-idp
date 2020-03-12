import atob from 'atob';
import btoa from 'btoa';
import * as WebAuthn from '../../../app/javascript/app/webauthn';

describe('WebAuthn', () => {
  beforeEach(() => {
    global.window = {
      atob,
      btoa,
      location: { hostname: 'testing.webauthn.js' },
    };
    global.Uint8Array = Buffer;
    global.navigator = {
      credentials: {
        create: () => {},
        get: () => {},
      },
    };
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

  describe('enrollWebauthnDevice', () => {
    const userId = '123';
    const userEmail = 'test@test.com';
    const userChallenge = '[1, 2, 3, 4, 5, 6, 7, 8]';
    const excludeCredentials = 'credential123,credential456';

    it('enrolls a device using the proper create options', (done) => {
      const expectedCreateOptions = {
        publicKey: {
          challenge: Buffer.from([1, 2, 3, 4, 5, 6, 7, 8]),
          rp: { name: 'testing.webauthn.js' },
          user: {
            id: Buffer.from([123, 0, 0, 0, 0, 0, 0, 0]),
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
          excludeCredentials: [
            {
              // encodes to 'credential123'
              id: Buffer.from([114, 183, 157, 122, 123, 98, 106, 93, 118]).buffer,
              type: 'public-key',
            },
            {
              // encodes to 'credential456'
              id: Buffer.from([114, 183, 157, 122, 123, 98, 106, 94, 57]).buffer,
              type: 'public-key',
            },
          ],
        },
      };

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
        userId, userEmail, userChallenge, excludeCredentials,
      }).then((result) => {
        expect(createCalled).to.eq(true);
        expect(result).to.deep.equal(expectedReturnValue);
      }).then(() => done()).catch(done);
    });

    it('forwards errors from the webauthn api', (done) => {
      const dummyError = new Error('dummy error');
      navigator.credentials.create = () => Promise.reject(dummyError);

      WebAuthn.enrollWebauthnDevice({
        userId, userEmail, userChallenge, excludeCredentials,
      }).catch((error) => {
        expect(error).to.equal(dummyError);
        done();
      }).catch(done);
    });
  });

  describe('verifyWebauthnDevice', () => {
    const userChallenge = '[1, 2, 3, 4, 5, 6, 7, 8]';
    const credentialIds = 'credential123,credential456';

    it('enrolls a device using the proper get options', (done) => {
      const expectedGetOptions = {
        publicKey: {
          challenge: Buffer.from([1, 2, 3, 4, 5, 6, 7, 8]),
          rpId: 'testing.webauthn.js',
          allowCredentials: [
            {
              // encodes to 'credential123'
              id: Buffer.from([114, 183, 157, 122, 123, 98, 106, 93, 118]).buffer,
              type: 'public-key',
            },
            {
              // encodes to 'credential456'
              id: Buffer.from([114, 183, 157, 122, 123, 98, 106, 94, 57]).buffer,
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
        userChallenge, credentialIds,
      }).then((result) => {
        expect(getCalled).to.eq(true);
        expect(result).to.deep.equal(expectedReturnValue);
      }).then(() => done()).catch(done);
    });

    it('forwards errors from the webauthn api', (done) => {
      const dummyError = new Error('dummy error');
      navigator.credentials.get = () => Promise.reject(dummyError);

      WebAuthn.verifyWebauthnDevice({
        userChallenge, credentialIds,
      }).catch((error) => {
        expect(error).to.equal(dummyError);
        done();
      }).catch(done);
    });
  });
});
