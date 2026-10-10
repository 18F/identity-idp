# delegated-access-account-page

## Purpose

Plan 5.3, Account → Delegated access. A dedicated page at `/account/delegated_access` lists every service provider approved for delegation, connected or not, with every active application that accepts it grouped by agency; the person approves applications in advance through a select-then-confirm flow, revokes one application, one service provider or everything through confirmation pages, and receives an account history event and an email for each change. It replaces the foundation's inline toggles under each connected-service entry.

## Requirements it satisfies

FR-CUX-12, FR-CUX-13, FR-CUX-14, FR-CEN-14, FR-CEN-15 (sign-out half). Companion §4.7 (ACC-1..6 as amended in §4.8 and §4.9).

## What it adds / removes and why

Adds:
- `Accounts::DelegatedAccessController#show` with `DelegatedAccessPresenter`: sections per active approved service provider plus any service provider the person still has a remembered approval for; applications from `DelegationApplications.accepting` plus any named by a remembered approval; `<details>` groups per agency, open when a group holds an approval (D23, D25). Remembered approvals only; current state only (D54).
- `Accounts::DelegatedAccess::ApprovalsController` (`new` renders `DelegationApprovalPresenter` with the consent-screen content; `create` records through `AccountDelegationApproval`, `source: account_page`, remembered for `TokenExchangeGrant::MAX_REMEMBER`) (D20). The selection is filtered through `TokenExchangeGrant.partition_current` so nothing already remembered is re-recorded.
- `Accounts::DelegatedAccess::RevocationsController` serving one application, one service provider and everything under `/account/delegated_access` with one confirmation page; `AccountDelegationRevocation` revokes with reason `user_revoked` in one transaction (D21, D54).
- `DelegatedAccessNotificationConcern`: `Event` types `delegation_approved` (31) and `delegation_revoked` (32), `UserMailer#delegation_approved`/`#delegation_revoked` to every confirmed address with the disavowal link (D22).
- `RevokeServiceProviderConsent#call` revokes the service provider's live approvals with reason `sp_disconnected` (FR-CEN-14). Sign-out touches nothing (FR-CEN-15).
- Shared content: `DelegationServiceProviderCard`, `shared/_delegation_service_provider_card` and `shared/_delegation_application_content`, used by the consent screen and the page so they cannot drift.
- `NavigationPresenter` entry and a link from each connected-services entry for an approved service provider (FR-CUX-14). Analytics `delegated_access_page_visited`, `delegation_account_approved`, `delegation_account_revoked`.

Removes:
- `_delegation_manage.html.erb`, `delegation-manage.ts`, `Accounts::ConnectedServices::TokenExchangeGrantsController`, `DelegationServiceProviderPresenter`, `AccountShowPresenter#delegation_for`, the `token_exchange_grant` route and `account.connected_apps.token_exchange.*` strings: their population (connected applications) and single-step toggle contradict D20 and D23.
- `DelegationApplications.connected_for`: the registry, not connection history, defines the offer (D4, D23).
- The `delegation_grant_toggled` analytics event.

## Key decisions

- D19 a dedicated page (rejected: inline controls per connected service); D23 unconnected service providers listed too (reverses the earlier deferral).
- D20 select-then-confirm; D21 every revocation confirms; D22 history event plus email; D25 collapsible agency groups, no pagination.
- D54 remembered approvals only, current state only, with "End all delegated access" (ACC-6); D24 token activity withdrawn in favor of the planned history view (D55, plan 5.15).

## Key files

Models: `app/models/event.rb` (two event types).
Services: `app/services/account_delegation_approval.rb`, `app/services/account_delegation_revocation.rb`, `app/services/revoke_service_provider_consent.rb`, `app/services/delegation_applications.rb`, `app/services/analytics_events.rb`.
Controllers/views: `app/controllers/accounts/delegated_access_controller.rb`, `app/controllers/accounts/delegated_access/approvals_controller.rb`, `app/controllers/accounts/delegated_access/revocations_controller.rb`, `app/controllers/concerns/delegated_access_notification_concern.rb`, `app/presenters/delegated_access_presenter.rb`, `app/presenters/delegation_approval_presenter.rb`, `app/presenters/delegation_service_provider_card.rb`, `app/presenters/navigation_presenter.rb`, `app/views/accounts/delegated_access/show.html.erb`, `approvals/new.html.erb`, `revocations/show.html.erb`, `app/views/shared/_delegation_service_provider_card.html.erb`, `app/views/shared/_delegation_application_content.html.erb`, `app/views/accounts/_connected_app.html.erb`, `app/mailers/user_mailer.rb`, `app/views/user_mailer/delegation_{approved,revoked}.html.erb`.
Migrations: none.
Specs: `spec/features/account_delegated_access_spec.rb`, the three controller specs under `spec/controllers/accounts/`, `spec/presenters/delegated_access_presenter_spec.rb`, `spec/presenters/delegation_approval_presenter_spec.rb`, `spec/services/account_delegation_{approval,revocation}_spec.rb`, `spec/services/revoke_service_provider_consent_spec.rb`, `spec/mailers/user_mailer_spec.rb`, `spec/views/accounts/delegated_access/show.html.erb_spec.rb`.
Config/locales: `config/routes.rb`, `config/locales/{en,es,fr,zh}.yml` (`account.delegated_access.*`).

## Commits

- `b74fbc3da1` FR-CUX-12, FR-CUX-13, FR-CUX-14, FR-CEN-14: account page for delegated access
- `e191c00e03` FR-CUX-13: the account page's approval step reads the shared partition
- `35d6ce85a9` FR-CUX-14: the revocation page names service providers from preloaded records

## How to review

Diff against `delegated-access-consent`. Check first: the routes block in `config/routes.rb`, `ApprovalsController#load_applications` (drops anything not accepting the service provider or already remembered), `AccountDelegationRevocation` scopes (one application, one service provider, all), `RevokeServiceProviderConsent` (reason `sp_disconnected`), and that the page shows `remember_until` approvals only. Specs: the feature spec, the controller specs, the mailer spec. Must not change for existing clients: connected-services entries for service providers not approved for delegation render as before; disconnecting such a service provider revokes nothing because it has no grants.

## Known open items and later amendments

- Amended 2026-10-11 (reuse review): the approval step reads `partition_current`; the revocation page preloads `service_provider_record` only for the all-providers scope (Bullet flagged an unused preload on the single-provider page).
- Not built here: token activity on rows (D24 withdrawn) and the history view (D55, plan 5.15).
- The token cascade behind `TokenExchangeGrant#revoke!` arrives with the token-exchange and lifecycle branches; here revocation marks the approval row.
- Held until the harness run (plan 6.1): views on `ButtonComponent`/`TagComponent`; `ServiceProvider#delegation_display_name_or_default`; a shared mailer instructions partial; folding `AccountDelegationApproval` into `TokenExchangeGrant.approve_all!`.
- The fraud-signals branch adds a release call to `ApprovalsController#create`; the operations branch renames the analytics property `issuer` to `service_provider_issuer`.

## Depends on / depended on by

Depends on `delegated-access-consent` (`partition_current`, `approve!`, the consent content). Depended on by `delegated-access-site-keys` only by position; the fraud-signals and operations branches touch the approvals controller and its analytics.
