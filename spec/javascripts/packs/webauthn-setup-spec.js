import { useSandbox } from '../support/sinon';
import useDefineProperty from '../support/define-property';

describe('webauthn-setup', () => {
  const defineProperty = useDefineProperty();
  const sandbox = useSandbox();
  let reloadWithError;

  beforeEach(async () => {
    defineProperty(window, 'location', { value: { search: null } });

    // Because webauthn-setup has side effects which trigger a call to `window.location.search`,
    // ensure that basic stubbing is in place before importing from the file.
    ({ reloadWithError } = await import('../../../app/javascript/packs/webauthn-setup'));
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
