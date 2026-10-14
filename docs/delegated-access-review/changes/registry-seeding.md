# Seed delegation content from environment configuration

Load approved application and service-provider content from configuration with deployment-environment restrictions and a separate local fixture.

## Review boundary

Compare with `dcl/delegated-access/billing-reports`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Load approved application and service-provider content from configuration with deployment-environment restrictions and a separate local fixture.

## Changed files

- `.gitignore`
- `.gitlab-ci.yml`
- `app/services/delegated_access_seeder.rb`
- `app/services/deploy_env_restriction.rb`
- `bin/setup`
- `config/delegated_access.localdev.yml`
- `db/seeds.rb`
- `dockerfiles/idp_review_app.Dockerfile`
- `lib/deploy/activate.rb`
- `lib/tasks/delegated_access.rake`
- `spec/services/delegated_access_seeder_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
