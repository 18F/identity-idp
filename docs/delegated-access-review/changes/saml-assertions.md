# Issue delegated SAML assertions with original authentication time

Adapt the existing assertion builder for delegated audiences and actors. Preserve the issuance authentication snapshot across renewal and later sign-ins.

## Review boundary

Compare with `dcl/delegated-access/delegated-claims`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Adapt the existing assertion builder for delegated audiences and actors. Preserve the issuance authentication snapshot across renewal and later sign-ins.

## Changed files

- `app/services/delegated_saml_assertion.rb`
- `config/initializers/saml_idp.rb`
- `lib/saml_idp_extensions/assertion_builder.rb`
- `spec/lib/saml_idp_extensions/assertion_builder_spec.rb`
- `spec/services/delegated_saml_assertion_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
