import sinon from 'sinon';
import { reloadWithError } from '../../../app/javascript/packs/webauthn-setup';

describe('webauthn-setup', () => {
  describe('reloadWithError', () => {
    it('reloads with error', () => {
      const setSearch = sinon.stub();

      reloadWithError('BadThingHappened', { search: '', setSearch });

      expect(setSearch).to.have.been.calledWith('error=BadThingHappened');
    });

    context('existing params', () => {
      it('reloads with error and retains existing params', () => {
        const setSearch = sinon.stub();

        reloadWithError('BadThingHappened', { search: '?foo=bar', setSearch });

        expect(setSearch).to.have.been.calledWith('foo=bar&error=BadThingHappened');
      });
    });

    context('existing error', () => {
      it('does not reload with error', () => {
        const setSearch = sinon.stub();

        reloadWithError('BadThingHappened', { search: '?error=BadThingHappened', setSearch });

        expect(setSearch).not.to.have.been.called();
      });

      context('force', () => {
        it('reloads with error', () => {
          const setSearch = sinon.stub();

          reloadWithError('BadThingHappened', {
            search: '?error=BadThingHappened',
            setSearch,
            force: true,
          });

          expect(setSearch).to.have.been.called();
        });
      });
    });
  });
});
