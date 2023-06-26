import { TextEncoder } from 'util';
import * as WebAuthn from '../../../app/javascript/app/webauthn';

describe('WebAuthn', () => {
  let originalNavigator;
  let originalCredentials;
  beforeEach(() => {
    originalNavigator = global.navigator;
    originalCredentials = global.navigator.credentials;
    global.navigator.credentials = {
      get: () => {},
    };
  });

  afterEach(() => {
    global.navigator = originalNavigator;
    global.navigator.credentials = originalCredentials;
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
