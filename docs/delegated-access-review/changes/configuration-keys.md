# Declare delegated-access configuration and translations

Define disabled-by-default switches, lifetimes, translations and shared analytics event methods before their callers. Feature activation and endpoint behavior remain in their owning review units.

## Review boundary

Compare with `dcl/delegated-access/dependency-security`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Define disabled-by-default switches, lifetimes, translations and shared analytics event methods before their callers. Feature activation and endpoint behavior remain in their owning review units.

## Changed files

- `app/services/analytics_events.rb`
- `config/application.yml.default`
- `config/locales/en.yml`
- `config/locales/es.yml`
- `config/locales/fr.yml`
- `config/locales/zh.yml`
- `lib/identity_config.rb`
- `spec/rails_helper.rb`
- `spec/support/delegated_access_helper.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
