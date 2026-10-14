# Update dependencies and secret-scanning exclusions

Carry the source dependency security updates and test-only example-key exclusions separately from authentication behavior.

## Review boundary

Compare with `dcl/delegated-access/site-key-personal-key`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Carry the source dependency security updates and test-only example-key exclusions separately from authentication behavior.

## Changed files

- `.gitleaks.toml`
- `package-lock.json`
- `package.json`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
