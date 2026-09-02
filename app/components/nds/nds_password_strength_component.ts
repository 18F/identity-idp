// This sidecar is intentionally named `nds_password_strength_component.ts`
// rather than `password_strength_component.ts`. Webpack keys every entry by
// basename only (see the `entries` glob in webpack.config.js, which spans both
// `app/components` and `app/components/nds`), and the legacy
// `app/components/password_strength_component.ts` already owns the
// `password_strength_component` entry. Matching that name here would collide
// and break the build, so the `nds_` prefix is load-bearing — do not "fix" it
// to match the component's filename.
//
// Tradeoff: because the basename no longer matches `NDS::PasswordStrengthComponent`,
// ViewComponent's sidecar auto-enqueue does not pick it up, so consumers must
// load it explicitly, e.g. `javascript_packs_tag_once('nds_password_strength_component')`.
import '@18f/identity-nds-password-strength/password-strength-element';
