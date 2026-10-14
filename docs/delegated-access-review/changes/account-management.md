# Let users review and revoke delegated access

Expose approvals and revocation controls with localized notifications. Hide the feature while disabled for ordinary users, while keeping existing standing approvals revocable during rollback.

## Review boundary

Compare with `dcl/delegated-access/consent-screen`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Expose approvals and revocation controls with localized notifications. Hide the feature while disabled for ordinary users, while keeping existing standing approvals revocable during rollback.

## Changed files

- `app/controllers/accounts/delegated_access/approvals_controller.rb`
- `app/controllers/accounts/delegated_access/revocations_controller.rb`
- `app/controllers/accounts/delegated_access_controller.rb`
- `app/controllers/concerns/delegated_access_notification_concern.rb`
- `app/mailers/user_mailer.rb`
- `app/models/event.rb`
- `app/presenters/delegated_access_presenter.rb`
- `app/presenters/delegation_approval_presenter.rb`
- `app/presenters/navigation_presenter.rb`
- `app/views/accounts/_connected_app.html.erb`
- `app/views/accounts/delegated_access/approvals/new.html.erb`
- `app/views/accounts/delegated_access/revocations/show.html.erb`
- `app/views/accounts/delegated_access/show.html.erb`
- `app/views/user_mailer/delegation_approved.html.erb`
- `app/views/user_mailer/delegation_revoked.html.erb`
- `config/routes.rb`
- `spec/controllers/accounts/delegated_access/approvals_controller_spec.rb`
- `spec/controllers/accounts/delegated_access/revocations_controller_spec.rb`
- `spec/controllers/accounts/delegated_access_controller_spec.rb`
- `spec/features/account_delegated_access_spec.rb`
- `spec/mailers/previews/user_mailer_preview.rb`
- `spec/mailers/user_mailer_spec.rb`
- `spec/presenters/delegated_access_presenter_spec.rb`
- `spec/presenters/delegation_approval_presenter_spec.rb`
- `spec/presenters/navigation_presenter_spec.rb`
- `spec/views/accounts/connected_services/show.html.erb_spec.rb`
- `spec/views/accounts/delegated_access/show.html.erb_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
