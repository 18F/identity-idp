# Verification record

Base: main `063d69fc915f073f5580f5105634d6215dbbb5bb` (confirmed against origin again before final validation). Ruby 3.4.10; isolated PostgreSQL databases and Redis on port 16389. JavaScript and CSS were rebuilt with `NODE_ENV=production` for the final browser comparison.

## Measured checks

- Broad pre-final run: 17,100 examples, 17 failures, 15 pending (seed 34329). Its failures drove the compatibility expectation corrections and explicit test configuration described below. This is not a claim of a green final suite.
- Affected-file run: 3,292 examples, 8 failures. Five were corrected authorization/CORS/userinfo expectations or behavior; three are the baseline browser failures below.
- Follow-up authorization, CORS and userinfo check: 146 examples, 0 failures after comparing recognized authorization inputs instead of cached URLs.
- Ruby formatting: 288 applicable files, no offenses. Generated schema and migrations use the repository's exclusions.
- All 390 distinct Ruby file versions across the final rebuilt sequence parsed successfully.
- Migration check: a scratch database loaded from main's schema upgraded successfully through the final migrations. The schema dump was reconciled to the migration result.
- Analytics and Attempts documentation/sorting checks passed.
- JavaScript suite: 999 passing, 0 failures. Production JavaScript/CSS build completed successfully (webpack warnings only).

The final full-stack attempt was interrupted after 28 minutes 39 seconds: 10,546 examples, 274 failures, 3 pending (seed 34329). The browser disconnected during the state-ID feature tests (`InvalidSessionIdError`), followed by cascading browser failures and host-mismatched redirects. This run is incomplete and is not evidence of a passing full suite. The fresh-process changed-area run completed 3,311 examples with four failures, all reproduced against the main checkout as described below. The reproofing-costing case and all state-ID cases passed in that run. The two remembered-device/TOTP examples that timed out in the broad run passed separately (2 examples, 0 failures). The underlying broad-run instability remains unresolved.

Secret scans: all 38 reconstructed commits passed Gitleaks with no leaks. The tracked-file snapshot produced 22 findings in existing fixtures, examples, baseline hashes and vendored assets. A scan of untouched main produced the same findings, with none introduced by this stack. Twenty-one findings are in byte-identical files; the remaining finding is on an unchanged line in `config/application.yml.default`. Ignored local dependencies and development configuration are outside the published tracked-tree snapshot.

Commit audit: all 38 commits form a linear chain from the recorded main SHA; each includes a changelog and Co-authored-by trailers for Kyle Neuman, Tai Groot, and SgtPluck.

## Baseline comparison

The following three failures reproduced with identical assertions on both the reconstructed stack and an untouched checkout of main at the SHA above, using the same production assets and local browser, seed 21711, and separate PostgreSQL databases (3 examples, 3 failures on each):

- `spec/features/saml/ial1_sso_spec.rb:73`: session timeout remains at the SMS MFA page instead of returning to sign-in.
- `spec/features/idv/steps/request_letter_step_spec.rb:37`: returning from address verification remains on verify-info instead of the expected GPO address message.
- `spec/features/webauthn/hidden_spec.rb:57`: the local browser exposes a platform authenticator where the test expects it hidden.

The fourth failure in the fresh changed-area run, `spec/views/layouts/application.html.erb_spec.rb:164`, also reproduced against main (1 example, 1 failure, seed 34329). It expects an unhashed `track-errors.js` filename; the production manifest uses a digested filename.

The baseline checkout had no tracked changes and used the same built assets and installed dependencies as the reconstruction, rather than an independent installation from main’s lockfile. These comparisons isolate the Ruby changes under the shared local environment; they are not a green-suite waiver or proof about production. Two additional broad-run browser failures (phone rate limiting and remembered-device timing) passed in the affected-file rerun. Two CSP tests now explicitly select client-side redirects, matching the scenario they assert instead of inheriting the test environment's server-side default.

## Compatibility and release limits

The regression matrix covers ignored DPoP/site-key inputs and unsupported delegation/document scopes across public, confidential and nullable client settings, through authorization, code redemption and userinfo. It also covers saved authorization decisions through rollback and locale changes, legacy request JSON, persistent token bindings, continuing approval, allowlist removal, revocation/publication races, original authentication time, default billing/report shapes and disabled navigation/endpoints.

Repository tests and a schema migration do not verify deployed configuration or third-party reference applications. Data-team notification and review remain pending. Do not call the feature release-ready while the required checks or disabled-mode contract are unverified or failing.

## Reproduction

Use Ruby 3.4.10, the repository test configuration, an isolated test database and Redis, and the production JavaScript/CSS build. Run `bundle exec rspec --seed 34329` for the broad suite and `npm test` for JavaScript. The fresh changed-area run selected the changed spec files plus existing SAML timeout, request-letter, WebAuthn, remembered-device, phone-rate-limit, costing, application-layout and state-ID scenarios. Run those baseline comparisons in a separate main checkout and database. Do not run two browser/RSpec suites concurrently against the same test services.
