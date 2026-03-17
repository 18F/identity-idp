# Top 5 Technical Debt Items

This document identifies the five most impactful areas of technical debt in the identity-idp
codebase, prioritized by their effect on maintainability, developer velocity, and long-term
sustainability.

---

## 1. Monolithic `AnalyticsEvents` Module (8,761 lines, 386 methods)

**File:** `app/services/analytics_events.rb`

**Problem:** All analytics event definitions for the entire application live in a single 8,761-line
module containing 386 methods. Every new feature that adds analytics tracking appends more methods
to this file. The methods follow a uniform pattern — each calls `track_event` with a name and
keyword arguments — but they span every domain in the application (authentication, identity
verification, account management, in-person proofing, fraud detection, etc.).

**Impact:**
- Merge conflicts are likely when multiple teams add events simultaneously
- Code review is difficult because reviewers must scroll through thousands of lines
- No domain boundaries make it hard to understand which events belong to which feature area
- Testing the module requires loading the entire file for any single event

**Recommended approach:** Split into domain-specific modules (e.g., `AuthenticationAnalyticsEvents`,
`IdvAnalyticsEvents`, `AccountAnalyticsEvents`, `FraudAnalyticsEvents`) that are composed into the
main analytics class via `include`. This preserves the existing public API while making each module
independently reviewable and testable.

---

## 2. Oversized Controller Concern: `VerifyInfoConcern` (700 lines, 60 methods)

**File:** `app/controllers/concerns/idv/verify_info_concern.rb`

**Problem:** This concern handles identity verification submission logic across multiple controller
actions. It mixes together:
- Verification submission orchestration (`shared_update`)
- Device profiling / ThreatMetrix session management
- Phone number selection for MFA and in-person proofing
- Resolution proofing via `Idv::Agent`
- Document capture session lifecycle management
- SSN and resolution rate limiting
- Extensive analytics logging

This violates the Single Responsibility Principle and makes the identity verification flow
difficult to trace, test, and modify.

**Impact:**
- Changes to one verification pathway risk breaking others
- High cognitive load for developers working on identity verification
- Difficult to unit test individual behaviors in isolation
- The concern is included in multiple controllers, amplifying the blast radius of bugs

**Recommended approach:** Extract focused collaborators:
- A service object for resolution proofing orchestration
- A separate concern or service for device profiling
- A dedicated object for phone number selection logic
- Keep the controller concern as a thin coordinator that delegates to these objects

---

## 3. Duplicated Raw SQL Across 44 Report Jobs

**Directory:** `app/jobs/reports/` (44 files, ~4,330 lines total)

**Problem:** The reporting layer contains 44 job classes that each construct and execute raw SQL
queries via `ActiveRecord::Base.connection.execute`. While the SQL is safely parameterized (using
`connection.quote` and `format`), the pattern is highly repetitive:

```ruby
params = { start: connection.quote(start), finish: connection.quote(finish) }
sql = format(<<~SQL, params)
  SELECT ... FROM ... WHERE created_at BETWEEN %{start} AND %{finish} ...
SQL
transaction_with_timeout { connection.execute(sql) }
```

Many reports query the same tables (`sp_return_logs`, `sp_costs`, `identities`) with slight
variations in grouping, filtering, or date ranges. There is no shared query-building abstraction
beyond the `BaseReport` class (which only provides timeout handling and S3 upload utilities) and
a small `QueryHelpers` module (13 lines with a single `quote` method).

**Impact:**
- Adding a new report requires copying and modifying an existing SQL template
- Schema changes (e.g., renaming a column) require updating SQL strings across many files
- No compile-time or type-level checks on query correctness
- Difficult to reuse query fragments across reports

**Recommended approach:** Introduce query builder objects or ActiveRecord scopes for common report
queries. The `app/services/db/` directory already has a few query objects (9 files) that could
serve as a pattern. Consolidating shared SQL fragments into composable query objects would reduce
duplication and make schema changes safer.

---

## 4. Forked and Pinned Gem Dependencies

**File:** `Gemfile`

**Problem:** Seven gems reference GitHub repositories instead of released versions on RubyGems:

| Gem | Source | Concern |
|-----|--------|---------|
| `saml_idp` | `18F/saml_idp` tag `v0.24.0-18f` | Custom fork diverged from upstream |
| `redis-session-store` | `18F/redis-session-store` tag `v1.0.2-18f` | Custom fork |
| `rack-attack` | `rack/rack-attack` pinned to commit SHA | Waiting for upstream release |
| `capybara-webmock` | `18F/capybara-webmock` branch `add-support-for-rack-3` | Unreleased branch |
| `identity-hostdata` | `18F/identity-hostdata` tag `v4.4.2` | Internal package |
| `identity-logging` | `18F/identity-logging` tag `v0.1.1` | Internal package |
| `identity_validations` | `18F/identity-validations` tag `v0.7.2` | Internal package |

Additionally, `zxcvbn` is pinned to `v0.1.12` with a comment warning against updates without
verifying behavior matches the JavaScript version `4.4.2`.

**Impact:**
- Forked gems (`saml_idp`, `redis-session-store`) miss upstream security patches and improvements
  unless manually merged
- Branch-pinned gems (`capybara-webmock`) are fragile and can break without warning
- Commit-SHA-pinned gems (`rack-attack`) create confusion about which version is actually in use
- Internal gems without RubyGems releases add friction for contributors setting up the project

**Recommended approach:**
- For `saml_idp` and `redis-session-store`: Contribute 18F patches upstream and migrate back to
  released gems, or publish the forks as distinct gems on RubyGems
- For `rack-attack`: Track the upstream issue and upgrade when a release includes the needed fix
- For `capybara-webmock`: Contribute Rack 3 support upstream or publish a released version of the
  fork
- For internal gems: Consider publishing to a private gem server or RubyGems organization

---

## 5. Accumulated Deprecated Code and Stale Feature Paths

**Locations:** Multiple files across the codebase

**Problem:** Several deprecated code paths remain in the codebase, adding confusion and maintenance
burden:

- **Deprecated User attributes** (`app/models/concerns/deprecated_user_attributes.rb`): The `email`
  and `confirmed_at` attributes on the `User` model are deprecated in favor of `EmailAddress`, but
  the deprecation shim and both code paths remain active.

- **Deprecated Profile status enums** (`app/models/profile.rb`): Two enum values are explicitly
  marked as no longer used (`gpo_verification_pending_NO_LONGER_USED`,
  `in_person_verification_pending_NO_LONGER_USED`) but cannot be removed without a migration to
  clean up the enum mapping.

- **Deprecated Vector of Trust (VoT)** (`app/services/component/parser.rb` and multiple spec
  files): The VoT system for determining Enhanced Identity Proofing Protocol (EIPP) has been
  deprecated in favor of `acr_values`, but VoT-related code paths and TODO comments remain
  (e.g., `# TODO:VOT: remove vector_of_trust param`).

- **123 skipped/pending tests** across the spec suite, many with reasons referencing deprecated
  features or incomplete implementations.

- **52 TODO/FIXME comments** across the codebase, with clusters around the Attempts API PII
  collection, event encryption, and metadata updates.

**Impact:**
- Developers must understand both the old and new code paths, increasing cognitive load
- Skipped tests represent untested behavior that may silently break
- TODO comments indicate known incomplete implementations that accumulate over time
- Deprecated enum values make the data model confusing for new contributors

**Recommended approach:**
- Complete the `User` → `EmailAddress` attribute migration and remove the deprecation concern
- Run a database migration to remap the unused Profile enum values, then remove them from the model
- Set a deadline to remove VoT code paths once all service providers have migrated to `acr_values`
- Triage the 123 skipped tests: delete tests for removed features, unskip tests for current
  features, and file issues for tests that need implementation work
- Review and resolve or convert the 52 TODO comments into tracked issues
