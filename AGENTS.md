# Working on the delegated-access branches of identity-idp

These instructions apply to `login-delegated-access` and every `delegated-access-*` feature branch
stacked on it. They describe how the work has been organized so far and must be followed for any
change, by a person or by an agent.

## 1. The three documents are the source of truth

- `docs/delegated-access-implementation-plan.md` (the plan: one section per feature, "As built"
  notes, section 9 decisions log with `Dnn` entries, section 7.5 environment-specific pieces)
- `docs/delegated-access-functional-requirements.md` (the `FR-…` requirements, Appendix D decisions)
- `docs/delegated-access-requirements.md` (the companion: protocol-level rows such as `EXC-…`,
  `INT-…`, `REF-…`, `ACC-…`, `BIL-…`, `ATT-…`, `SAML-…`, dated amendment subsections, Appendix E
  decision rows `Ennn`)

They live **only on `login-delegated-access`**. Feature branches are code-only and never commit
under `docs/`. Copies on Google Drive are stale and carry a banner saying so.

### Keep them current, in the same unit of work as the code

- A **requirement changes** (the product owner decides something, an interview resolves a
  question, a reviewer's recommendation is accepted): record it the same day before or with the
  code. Add a dated entry to the plan's section 9 decisions log (`Dnn — Title.` with rationale and
  the rejected alternative), the matching item in the FR doc's Appendix D, amend the affected
  `FR-…` rows in place, add or amend companion rows in that section's dated "Amendments" subsection
  and an Appendix E row. Strike resolved open questions as `~~…~~ Decided <date> (Dnn)`.
- **Code lands or changes in a way the documents no longer describe**: add or update the
  feature's "**As built, <date> (`branch`, N commits on `parent`).**" numbered block in the plan,
  the "**Implemented <date> (feature 5.x …):**" paragraph in the FR doc, and the "**As built**"
  paragraph (plus any "(amend <date>)" rows) in the companion. Name classes, routes, migrations,
  config keys, analytics events and exact verification counts. Record deviations from the
  earlier text as decisions, never silently.
- Product-owner notes appear in the plan as `(note: …)` lines. Treat each as an instruction:
  resolve it (ask if needed), fold the answer into the text, and remove or strike the note.
- Before implementing a feature, resolve its open decisions with the product owner (an
  interview), record them as above, then build.

Docs commits on the base are pushed to GitHub immediately. Feature branches rebase onto the base
when they next need code from below them; they never need to rebase for docs alone.

## 2. Branch structure

A linear stack of code-only feature branches, each starting from the previous one's tip; the
local branch `delegated-access-integration` points at the top. Current order:

```
login-delegated-access (base + docs)
 → delegated-access-registry         (5.1)
 → delegated-access-consent          (5.2)
 → delegated-access-account-page     (5.3)
 → delegated-access-site-keys        (5.16, ported per-site-keys pull requests)
 → delegated-access-dpop             (5.10, key binding for the public client)
 → delegated-access-token-exchange   (5.4)
 → delegated-access-token-lifecycle  (5.5)
 → delegated-access-introspection    (5.6)
 → delegated-access-saml-assertions  (5.9)
 → delegated-access-operations       (5.11)
 → delegated-access-billing-reporting(5.8)
 → delegated-access-fraud-signals    (5.7)
 → delegated-access-config-content   (5.17, content seeded from identity-idp-config)
```

- Plan section 8 maps every branch to its feature section and requirement identifiers and gives
  the reading and review order (each branch is reviewed as the diff against the one below it).
- Branch names say what the branch delivers; no numbers or abbreviations.
- A fix belongs in the branch that owns the behavior; rebase the branches above it afterwards
  (`git rebase <previous tip>` in each worktree, in stack order). Acceptance is a fast-forward of
  `login-delegated-access`.
- Each branch has a worktree of the same name under `~/coding/worktrees/`. Never merge sibling
  branches; cherry-pick and rebase only.
- No compatibility or dead code: nothing on these branches is in production, so drop and replace
  rather than keeping `legacy`/`old` variants or flags "just in case".
- Existing clients must see identical behavior. Anything new is keyed off the new records
  (public client approved for delegation, delegation scopes, bound tokens), never off a
  code path shared with current integrations.

## 3. Code and commit conventions

- Vocabulary: "service provider" (never "broker"), "application" for an agency's record,
  "resource server" or "agency API" for an API URL. Fictitious names only in code, fixtures,
  comments and the plan: MyBenefits Assistant (Office of Benefits Coordination, agency 100);
  Department of Housing Support (101) → Housing Assistance Records; National Retirement
  Administration (102) → Retirement Benefits Portal. Never name a real agency or America.gov there.
- Comments are thorough and developer-followable, inside complex logic too, written in
  functional language with RFC citations. No requirement identifiers in code or comments. No
  design history or forward references ("previous design", "feature X replaces this later");
  that context goes in the docs and commit messages. Present external facts (for example the
  Dashboard lacking fields) are fine.
- Commit subjects mirror the functional requirement identifiers ("FR-TOK-1, FR-TOK-3: …");
  bodies may cite companion rows. Ported commits keep their original author and message.
- Locale strings in en, es, fr and zh; the files are flat dotted keys kept sorted; single-quote a
  value that contains a colon or starts with `%{`.
- Analytics methods stay alphabetical with YARD docs (`make lint_analytics_events
  lint_analytics_events_sorted`); Attempts events need schema files under
  `docs/attempts-api/schemas` (`make lint_tracker_events`).
- Bullet is on in feature specs: load related records once (`live_by_application`, explicit
  preloads) and never preload what a request will not read.
- Migrations are additive and strong_migrations-safe; `db/schema.rb` on a branch reflects only
  that branch's migrations (shared development databases will dump more; revert the extra lines).

## 4. Local before CI

Nothing is pushed until it passes locally: the touched specs, `spec/i18n_spec.rb`, rubocop on
changed files, the analytics and tracker lints, and, before pushing a branch, the full suite
on the top of the stack. Then `gitleaks git --redact --log-opts="<base>..HEAD" .` on the commit
range; report the result with the push.

Fresh worktree checklist: symlink `config/*.localdev.yml` → `config/*.yml` (this includes
`config/delegated_access.localdev.yml` → `config/delegated_access.yml`, which `bin/setup` also
links and `db:seed` reads), `certs` → `certs.example`, `keys` → `keys.example`; copy
`config/application.yml` from a sibling worktree; symlink `pwned_passwords/pwned_passwords.txt`; `mkdir -p tmp/pids`;
`npm ci && NODE_ENV=development npm run build && npm run build:css` (a production build digests
pack names and breaks a layout spec). Browser specs route through the capybara-webmock proxy on
port 9292, which the sample service provider also uses when the local stack is up; run them with
a one-off require that sets `Capybara::Webmock.port_number` to a free port. Never run two rspec
processes in one worktree. Worktrees share the development and test databases and Redis; when
several run specs at once, verify on a dedicated test database and treat failures caused by a
sibling's migration or `flushdb` as environment noise, then rerun.

GitHub vulnerability alerts are fixed on the base branch when the fix does not change behavior
(then the stack rebases); otherwise they are reported to the product owner.

## 5. Related repositories

- Service provider reference app (browser public client): `github.com/GSA-TTS/identity-sts-sinatra`,
  branch `main`. Agency reference APIs: `github.com/18F/identity-oidc-sinatra` and
  `github.com/18F/identity-saml-sinatra`, branch `login-delegated-access`. The contract between
  them and this repository is the `development` section of `config/delegated_access.localdev.yml`
  (one delegation scope per application, issuers, resource identifiers, redirect URIs) plus the
  end-to-end harness in the service provider app; change one side only together with the other.
- Configuration repository: `github.com/18F/identity-idp-config`, branch `delegated-access`.
  Production content for delegated access (agency consent content, applications with their
  consent text, logos and API URLs, service providers approved for delegation) lives there as
  `delegated_access.yml`, edited by pull request and seeded by `db:seed` in every environment
  (plan D77, 5.17); there is no admin interface for it. Entries carry `restrict_to_deploy_env`
  like service providers; fictitious entries are `sandbox`. Deploy clones that repository at
  `main`, so its branch is not deployable until merged.
- GitLab `lg/*` projects are pull mirrors of the GitHub repositories; do not push to them.
- Billing changes follow the local `login-billing` skill and the data-team items recorded in the
  plan's 5.8 notes.

## 6. Environment-specific pieces

Plan section 7.5 lists what applies only locally or in a sandbox (the localdev fixture, linked to
`config/delegated_access.yml` by `bin/setup` where a deployed environment links the
identity-idp-config file instead, the three fictitious logos, sample certificate names,
development `application.yml` values, the webmock port workaround) and what is not environment-specific although it looks it (CORS rules for the
browser-callable endpoints, discovery metadata gated by the switch, alert-threshold keys). Add
to that table whenever a new local-only piece is introduced, so it can be removed or disabled
deliberately.
