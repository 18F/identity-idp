import quibble from 'quibble';
import { screen, waitFor } from '@testing-library/dom';
import baseUserEvent from '@testing-library/user-event';
import { rest } from 'msw';
import { setupServer } from 'msw/node';
import type { SetupServer } from 'msw/node';
import type { SinonStub } from 'sinon';
import { useSandbox } from '@18f/identity-test-helpers';

describe('ManageableAuthenticatorElement', () => {
  const sandbox = useSandbox({ useFakeTimers: true });
  const { clock } = sandbox;
  const userEvent = baseUserEvent.setup({ advanceTimers: clock.tick });
  let forceSubmit: SinonStub;
  let server: SetupServer;

  function createElement() {
    document.body.innerHTML = `
      <lg-manageable-authenticator
        api-url="${window.location.origin}/api/manage"
        configuration-name="configuration-name"
        unique-id="configuration-123"
        reauthenticate-at="2023-12-07T00:10:00.000Z"
        reauthentication-url="#reauthenticate"
      >
        <script type="application/json" class="manageable-authenticator__strings">
          {"renamed":"Renamed","delete_confirm":"Are you sure?","deleted":"Deleted"}
        </script>
        <div class="manageable-authenticator__edit" tabindex="-1" role="group" aria-labelledby="manageable-authenticator-manage-accessible-label-configuration-123">
          <div class="usa-alert manageable-authenticator__alert" tabindex="-1" role="status">
            <div class="usa-alert__body">
              <p class="usa-alert__text"></p>
            </div>
          </div>
          <form class="manageable-authenticator__rename">
            <input class="manageable-authenticator__rename-input" aria-label="Nickname" value="configuration-name">
            <lg-spinner-button class="manageable-authenticator__save-rename-button" long-wait-duration-ms="Infinity">
              <button name="button" type="submit" class="usa-button">
                <span class="spinner-button__content">Save</span>
                <span class="spinner-dots spinner-dots--centered" aria-hidden="true">
                  <span class="spinner-dots__dot"></span>
                  <span class="spinner-dots__dot"></span>
                  <span class="spinner-dots__dot"></span>
                </span>
              </button>
              <div role="status" data-message="Saving…" class="spinner-button__action-message"></div>
            </lg-spinner-button>
            <button name="button" type="button" class="manageable-authenticator__cancel-rename-button">Cancel</button>
          </div>
        </form>
        <div class="manageable-authenticator__details">
          <span class="usa-sr-only">Nickname:</span>
          <strong class="manageable-authenticator__name manageable-authenticator__details-name">
            configuration-name
          </strong>
          <button name="button" type="button" class="manageable-authenticator__rename-button">Rename</button>
          <lg-spinner-button class="manageable-authenticator__delete-button" long-wait-duration-ms="Infinity">
            <button name="button" type="button" class="usa-button">
              <span class="spinner-button__content">Delete</span>
              <span class="spinner-dots spinner-dots--centered" aria-hidden="true">
                <span class="spinner-dots__dot"></span>
                <span class="spinner-dots__dot"></span>
                <span class="spinner-dots__dot"></span>
              </span>
            </button>
            <div role="status" data-message="Deleting…" class="spinner-button__action-message"></div>
          </lg-spinner-button>
          <button name="button" type="button" class="manageable-authenticator__done-button">Done</button>
        </div>
        <div class="manageable-authenticator__summary">
          <div class="manageable-authenticator__name manageable-authenticator__summary-name">configuration-name</div>
          <div class="manageable-authenticator__actions">
            <button name="button" type="button" class="manageable-authenticator__manage-button">
              <span aria-hidden="true">Manage</span>
              <span class="usa-sr-only" id="manageable-authenticator-manage-accessible-label-configuration-123">
                Manage <span class="manageable-authenticator__name">configuration-name</span>
              </span>
            </button>
          </div>
        </div>
      </lg-manageable-authenticator>
    `;

    return document.body.querySelector('lg-manageable-authenticator')!;
  }

  before(async () => {
    forceSubmit = sandbox.stub();
    quibble('@18f/identity-url', { forceSubmit });
    await Promise.all([
      import('./manageable-authenticator-element'),
      import('@18f/identity-spinner-button/spinner-button-element'),
    ]);
    server = setupServer();
    server.listen();
  });

  beforeEach(() => {
    sandbox.clock.setSystemTime(new Date('2023-12-07T00:00:00Z'));
    server.resetHandlers();
  });

  after(() => {
    server.close();
  });

  it('shows initial manage state', () => {
    const element = createElement();

    expect(element.classList.contains('manageable-authenticator--editing')).to.be.false();
  });

  context('when selected after reauthentication', () => {
    beforeEach(() => {
      jsdom.reconfigure({ url: 'http://example.test/?manage_authenticator=configuration-123' });
    });

    it('shows initial manage state', () => {
      const initialHistoryLength = window.history.length;
      sandbox.spy(HTMLElement.prototype, 'scrollIntoView');
      const element = createElement();

      expect(element.classList.contains('manageable-authenticator--editing')).to.be.true();
      expect(window.location.href).to.equal('http://example.test/');
      expect(window.history).to.have.lengthOf(initialHistoryLength);
      expect(HTMLElement.prototype.scrollIntoView).to.have.been.called();
    });
  });

  describe('clicking manage', () => {
    it('toggles edit details', async () => {
      const element = createElement();

      await userEvent.click(screen.getByRole('button', { name: 'Manage configuration-name' }));

      const detailPanel = screen.getByRole('group');

      await waitFor(() =>
        expect(element.classList.contains('manageable-authenticator--editing')).to.be.true(),
      );
      expect(document.activeElement).to.equal(detailPanel);
    });

    context('with reauthentication required', () => {
      beforeEach(() => {
        sandbox.clock.setSystemTime(new Date('2023-12-07T15:00:00Z'));
      });

      it('redirects the user to reauthenticate', async () => {
        createElement();

        await userEvent.click(screen.getByRole('button', { name: 'Manage configuration-name' }));

        await expect(forceSubmit).to.eventually.be.calledWith('#reauthenticate');
      });
    });
  });

  describe('viewing manage details', () => {
    it('cancels and returns focus to manage button when clicking done', async () => {
      const element = createElement();

      await userEvent.click(screen.getByRole('button', { name: 'Manage configuration-name' }));
      await waitFor(() =>
        expect(element.classList.contains('manageable-authenticator--editing')).to.be.true(),
      );

      await userEvent.click(screen.getByRole('button', { name: 'Done' }));
      expect(element.classList.contains('manageable-authenticator--editing')).to.be.false();
      expect(document.activeElement).to.equal(
        screen.getByRole('button', { name: 'Manage configuration-name' }),
      );
    });

    it('cancels and returns focus to manage button when pressing escape', async () => {
      const element = createElement();

      await userEvent.click(screen.getByRole('button', { name: 'Manage configuration-name' }));
      await waitFor(() =>
        expect(element.classList.contains('manageable-authenticator--editing')).to.be.true(),
      );

      await userEvent.keyboard('{Escape}');
      expect(element.classList.contains('manageable-authenticator--editing')).to.be.false();
      expect(document.activeElement).to.equal(
        screen.getByRole('button', { name: 'Manage configuration-name' }),
      );
    });
  });

  describe('renaming', () => {
    it('focuses the input at the end of the current name', async () => {
      const element = createElement();

      await userEvent.click(screen.getByRole('button', { name: 'Manage configuration-name' }));
      await waitFor(() =>
        expect(element.classList.contains('manageable-authenticator--editing')).to.be.true(),
      );

      await userEvent.click(screen.getByRole('button', { name: 'Rename' }));
      const renameInput = screen.getByRole<HTMLInputElement>('textbox', { name: 'Nickname' });
      expect(document.activeElement).to.equal(renameInput);

      await userEvent.keyboard('appended');
      expect(renameInput.value).to.equal('configuration-nameappended');
    });

    it('cancels (resets edit state) and returns focus to manage button when pressing escape', async () => {
      const element = createElement();

      await userEvent.click(screen.getByRole('button', { name: 'Manage configuration-name' }));
      await waitFor(() =>
        expect(element.classList.contains('manageable-authenticator--editing')).to.be.true(),
      );

      await userEvent.click(screen.getByRole('button', { name: 'Rename' }));
      expect(element.classList.contains('manageable-authenticator--renaming')).to.be.true();

      await userEvent.keyboard('{Escape}');
      expect(element.classList.contains('manageable-authenticator--editing')).to.be.false();
      expect(element.classList.contains('manageable-authenticator--renaming')).to.be.false();
      expect(document.activeElement).to.equal(
        screen.getByRole('button', { name: 'Manage configuration-name' }),
      );
    });

    context('successful response from server when submitting rename', () => {
      beforeEach(() => {
        server.use(
          rest.put('/api/manage', (_req, res, ctx) =>
            res(ctx.json({ success: true }), ctx.status(200)),
          ),
        );
      });

      it('returns the user to summary details with new name for successful save', async () => {
        const element = createElement();

        await userEvent.click(screen.getByRole('button', { name: 'Manage configuration-name' }));
        await waitFor(() =>
          expect(element.classList.contains('manageable-authenticator--editing')).to.be.true(),
        );

        await userEvent.click(screen.getByRole('button', { name: 'Rename' }));
        await userEvent.keyboard('-new');
        const saveButton = screen.getByRole('button', { name: 'Save' });

        // Check for spinning while saving
        await userEvent.click(saveButton);
        expect(saveButton.closest('.spinner-button--spinner-active')).to.exist();

        // Change for ARIA live region content update
        const alert = screen
          .getAllByRole('status')
          .find((candidate) => !candidate.closest('lg-spinner-button'))!;
        expect(alert.textContent!.trim()).to.be.empty();
        await waitFor(() => expect(alert.textContent!.trim()).to.equal('Renamed'));
        expect(alert.classList.contains('usa-alert--success')).to.be.true();
        expect(alert.classList.contains('usa-alert--error')).to.be.false();

        // Check return to details
        expect(element.classList.contains('manageable-authenticator--renaming')).to.be.false();
        expect(element.classList.contains('manageable-authenticator--editing')).to.be.true();

        // Check for focus target
        const detailPanel = screen.getByRole('group', { name: 'Manage configuration-name-new' });
        expect(document.activeElement).to.equal(detailPanel);

        // Check for new name
        expect(screen.getAllByText('configuration-name-new')).not.to.be.empty();

        // Check for spinner button reset
        await userEvent.click(screen.getByRole('button', { name: 'Rename' }));
        expect(saveButton.closest('.spinner-button--spinner-active')).not.to.exist();
      });
    });

    context('failed response from server when submitting rename', () => {
      beforeEach(() => {
        server.use(
          rest.put('/api/manage', (_req, res, ctx) =>
            res(ctx.json({ error: 'Uh oh!' }), ctx.status(400)),
          ),
        );
      });

      it('keeps the user on the rename panel and displays the received error', async () => {
        const element = createElement();

        await userEvent.click(screen.getByRole('button', { name: 'Manage configuration-name' }));
        await waitFor(() =>
          expect(element.classList.contains('manageable-authenticator--editing')).to.be.true(),
        );

        await userEvent.click(screen.getByRole('button', { name: 'Rename' }));
        await userEvent.keyboard('-new');
        const saveButton = screen.getByRole('button', { name: 'Save' });
        await userEvent.click(saveButton);

        // Change for ARIA live region content update
        const alert = screen
          .getAllByRole('status')
          .find((candidate) => !candidate.closest('lg-spinner-button'))!;
        expect(alert.textContent!.trim()).to.be.empty();
        await waitFor(() => expect(alert.textContent!.trim()).to.equal('Uh oh!'));
        expect(alert.classList.contains('usa-alert--success')).to.be.false();
        expect(alert.classList.contains('usa-alert--error')).to.be.true();

        // Check still renaming
        expect(element.classList.contains('manageable-authenticator--renaming')).to.be.true();
        expect(element.classList.contains('manageable-authenticator--editing')).to.be.true();

        // Check for focus target
        expect(document.activeElement).to.equal(saveButton);

        // Check that new name was not assigned
        expect(screen.queryAllByText('configuration-name-new')).to.be.empty();

        // Check for spinner button reset
        expect(saveButton.closest('.spinner-button--spinner-active')).not.to.exist();
      });
    });

    context('with reauthentication required', () => {
      it('redirects the user to reauthenticate', async () => {
        const element = createElement();

        await userEvent.click(screen.getByRole('button', { name: 'Manage configuration-name' }));
        await waitFor(() =>
          expect(element.classList.contains('manageable-authenticator--editing')).to.be.true(),
        );

        await userEvent.click(screen.getByRole('button', { name: 'Rename' }));
        await userEvent.keyboard('-new');

        sandbox.clock.setSystemTime(new Date('2023-12-07T15:00:00Z'));
        await userEvent.click(screen.getByRole('button', { name: 'Save' }));

        await expect(forceSubmit).to.eventually.be.calledWith('#reauthenticate');
      });
    });
  });

  describe('deleting', () => {
    it('prompts the user and resets button if they cancel', async () => {
      const element = createElement();

      await userEvent.click(screen.getByRole('button', { name: 'Manage configuration-name' }));
      await waitFor(() =>
        expect(element.classList.contains('manageable-authenticator--editing')).to.be.true(),
      );

      sandbox.stub(window, 'confirm').returns(false);
      const deleteButton = screen.getByRole('button', { name: 'Delete' });
      await userEvent.click(deleteButton);

      expect(document.activeElement).to.equal(deleteButton);
      expect(deleteButton.closest('.spinner-button--spinner-active')).not.to.exist();
    });

    context('successful response from server when deleting', () => {
      beforeEach(() => {
        server.use(
          rest.delete('/api/manage', (_req, res, ctx) =>
            res(ctx.json({ success: true }), ctx.status(200)),
          ),
        );
      });

      it('deletes the authenticator and displays a confirmation message', async () => {
        const element = createElement();

        await userEvent.click(screen.getByRole('button', { name: 'Manage configuration-name' }));
        await waitFor(() =>
          expect(element.classList.contains('manageable-authenticator--editing')).to.be.true(),
        );

        sandbox.stub(window, 'confirm').returns(true);
        const deleteButton = screen.getByRole('button', { name: 'Delete' });
        await userEvent.click(deleteButton);

        const alert = screen
          .getAllByRole('status')
          .find((candidate) => !candidate.closest('lg-spinner-button'))!;
        expect(alert.textContent!.trim()).to.be.empty();
        await waitFor(() => expect(alert.textContent!.trim()).to.equal('Deleted'));

        expect(alert.classList.contains('usa-alert--success')).to.be.true();
        expect(alert.classList.contains('usa-alert--error')).to.be.false();
        expect(document.activeElement).to.equal(alert);
        expect(element.classList.contains('manageable-authenticator--deleted')).to.be.true();
      });
    });

    context('failed response from server when deleting', () => {
      beforeEach(() => {
        server.use(
          rest.delete('/api/manage', (_req, res, ctx) =>
            res(ctx.json({ error: 'Uh oh!' }), ctx.status(400)),
          ),
        );
      });

      it('displays the error message', async () => {
        const element = createElement();

        await userEvent.click(screen.getByRole('button', { name: 'Manage configuration-name' }));
        await waitFor(() =>
          expect(element.classList.contains('manageable-authenticator--editing')).to.be.true(),
        );

        sandbox.stub(window, 'confirm').returns(true);
        const deleteButton = screen.getByRole('button', { name: 'Delete' });
        await userEvent.click(deleteButton);

        const alert = screen
          .getAllByRole('status')
          .find((candidate) => !candidate.closest('lg-spinner-button'))!;
        expect(alert.textContent!.trim()).to.be.empty();
        await waitFor(() => expect(alert.textContent!.trim()).to.equal('Uh oh!'));

        expect(alert.classList.contains('usa-alert--success')).to.be.false();
        expect(alert.classList.contains('usa-alert--error')).to.be.true();
        expect(document.activeElement).to.equal(deleteButton);
        expect(deleteButton.closest('.spinner-button--spinner-active')).not.to.exist();
        expect(element.classList.contains('manageable-authenticator--deleted')).to.be.false();
      });
    });

    context('with reauthentication required', () => {
      it('redirects the user to reauthenticate', async () => {
        const element = createElement();

        await userEvent.click(screen.getByRole('button', { name: 'Manage configuration-name' }));
        await waitFor(() =>
          expect(element.classList.contains('manageable-authenticator--editing')).to.be.true(),
        );

        sandbox.stub(window, 'confirm').returns(true);
        sandbox.clock.setSystemTime(new Date('2023-12-07T15:00:00Z'));
        await userEvent.click(screen.getByRole('button', { name: 'Delete' }));

        await expect(forceSubmit).to.eventually.be.calledWith('#reauthenticate');
      });
    });
  });
});
