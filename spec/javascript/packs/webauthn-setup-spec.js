import sinon from 'sinon';
import { reloadWithError } from '../../../app/javascript/packs/webauthn-setup';

describe('webauthn-setup', () => {
  describe('reloadWithError', () => {
    it('reloads with error', () => {
      const navigate = sinon.stub();

      reloadWithError('BadThingHappened', { initialURL: 'http://example.com', navigate });

      const navigateURL = new URL(navigate.getCall(0).args[0]);
      expect(navigateURL.search).to.equal('?error=BadThingHappened');
    });

    context('existing params', () => {
      it('reloads with error and retains existing params', () => {
        const navigate = sinon.stub();

        reloadWithError('BadThingHappened', { initialURL: 'http://example.com?foo=bar', navigate });

        const navigateURL = new URL(navigate.getCall(0).args[0]);
        expect(navigateURL.search).to.equal('?foo=bar&error=BadThingHappened');
      });
    });

    context('existing error', () => {
      it('does not reload with error', () => {
        const navigate = sinon.stub();

        reloadWithError('BadThingHappened', {
          initialURL: 'http://example.com?error=BadThingHappened',
          navigate,
        });

        expect(navigate).not.to.have.been.called();
      });

      context('force', () => {
        it('reloads with error', () => {
          const navigate = sinon.stub();

          reloadWithError('BadThingHappened', {
            initialURL: 'http://example.com?error=BadThingHappened',
            navigate,
            force: true,
          });

          expect(navigate).to.have.been.called();
        });
      });
    });
  });
});
