import { useDefineProperty } from '@18f/identity-test-helpers';
import { useSandbox } from '../support/sinon';
import { reloadWithError } from '../../../app/javascript/packs/webauthn-setup';

describe('webauthn-setup', () => {
  const defineProperty = useDefineProperty();
  const sandbox = useSandbox();

  beforeEach(() => {
    defineProperty(window, 'location', { value: { search: null } });
  });

  describe('reloadWithError', () => {
    function stubSearch(initialValue = '') {
      const search = sandbox.stub();
      sandbox
        .stub(window.location, 'search')
        .set(search)
        .get(() => initialValue);
      return search;
    }

    it('reloads with error', () => {
      const search = stubSearch();

      reloadWithError('BadThingHappened');

      expect(search).to.have.been.calledWith('error=BadThingHappened');
    });

    context('existing params', () => {
      it('reloads with error and retains existing params', () => {
        const search = stubSearch('?foo=bar');

        reloadWithError('BadThingHappened');

        expect(search).to.have.been.calledWith('foo=bar&error=BadThingHappened');
      });
    });

    context('existing error', () => {
      it('does not reload with error', () => {
        const search = stubSearch('?error=BadThingHappened');

        reloadWithError('BadThingHappened');

        expect(search).not.to.have.been.called();
      });

      context('force', () => {
        it('reloads with error', () => {
          const search = stubSearch('?error=BadThingHappened');

          reloadWithError('BadThingHappened', { force: true });

          expect(search).to.have.been.called();
        });
      });
    });
  });
});
