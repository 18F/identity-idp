#!/usr/bin/env bash
# Read-only inventory of the local-only and sandbox-only markers in an identity-idp worktree,
# grouped by category, to compare with references/local-only-changes.md (and plan section 7.5).
# Prints file:line hits; values from config/application.yml are never printed, only key names.
#
#   local_only_changes.sh            inventory the identity-idp worktree (IDP_DIR, default: cwd
#                                    if it is an identity-idp checkout, else the skill's repository)
#   SP_DIR=... OIDC_AGENCY_DIR=... SAML_AGENCY_DIR=...  also inventory the reference apps
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../../../.." && pwd)
if [ -z "${IDP_DIR:-}" ]; then
  if [ -r "$PWD/config/application.yml.default" ]; then IDP_DIR=$PWD; else IDP_DIR=$REPO_ROOT; fi
fi
[ -r "$IDP_DIR/config/application.yml.default" ] || { echo "ERROR: $IDP_DIR is not an identity-idp checkout" >&2; exit 1; }

heading() { printf '\n== %s ==\n' "$*"; }
# grep that never fails the script and prints relative paths.
hits() {
  local dir=$1; shift
  (cd "$dir" && grep -n -E "$@" 2>/dev/null) | sed "s|^|  |" || true
}
exists() {
  local path=$1
  if [ -L "$path" ]; then printf '  %s -> %s\n' "$path" "$(readlink "$path")"
  elif [ -e "$path" ]; then printf '  %s (present)\n' "$path"
  else printf '  %s (absent)\n' "$path"; fi
}

echo "identity-idp worktree: $IDP_DIR"

heading "Fixture config/delegated_access.localdev.yml (local: development; sandbox: production)"
hits "$IDP_DIR" '^(development|production|test):|restrict_to_deploy_env|DELEGATION_(SP|OIDC_AGENCY|SAML_AGENCY)_URL|logo:' config/delegated_access.localdev.yml
heading "Link of the fixture and its ignore rule"
(cd "$IDP_DIR" && exists config/delegated_access.yml)
hits "$IDP_DIR" 'delegated_access' bin/setup .gitignore
heading "Seeder entry points (not environment-specific)"
hits "$IDP_DIR" 'DelegatedAccessSeeder|delegated_access' db/seeds.rb lib/tasks/delegated_access.rake lib/deploy/activate.rb
heading "Review-app and CI copies of the fixture"
hits "$IDP_DIR" 'delegated_access' .gitlab-ci.yml dockerfiles/*.Dockerfile
heading "Development config/application.yml (key names only; gitignored)"
if [ -r "$IDP_DIR/config/application.yml" ]; then
  (cd "$IDP_DIR" && grep -n -o -E '^[[:space:]]*(token_exchange_[a-z_]+|attempts_api_enabled|historical_attempts_api_enabled|allowed_attempts_providers|otp_delivery_blocklist_maxretry|short_term_phone_otp_max_attempts|document_images_sharing_[a-z_]+|redis_[a-z_]*url)' config/application.yml | sed 's|^|  config/application.yml:|') || true
else
  echo "  config/application.yml absent"
fi
heading "Defaults in config/application.yml.default (the production-off values)"
hits "$IDP_DIR" '^(token_exchange_[a-z_]+|allowed_attempts_providers|attempts_api_enabled|document_images_sharing_[a-z_]+|redis_attempts_api_url):' config/application.yml.default
heading "Sample certificate names and files"
hits "$IDP_DIR" "^\s*- '(rs_records_demo|sp_sinatra_demo)'" config/delegated_access.localdev.yml
(cd "$IDP_DIR" && exists certs && exists certs/sp/rs_records_demo.crt && exists certs.example/sp/sp_sinatra_demo.crt)
heading "Capybara-webmock proxy port (override lives outside the repository)"
hits "$IDP_DIR" 'Webmock.port_number' spec/support/capybara.rb spec/rails_helper.rb
heading "Not environment-specific although it looks it: CORS and the discovery switch"
hits "$IDP_DIR" "resource '/api/openid_connect/(token|revoke|introspect)'|Rack::Cors" config/application.rb
hits "$IDP_DIR" 'allowed_redirect_uri\?' lib/identity_cors.rb
hits "$IDP_DIR" 'token_exchange_enabled$' app/presenters/openid_connect_configuration_presenter.rb app/controllers/concerns/openid_connect/delegated_endpoint_concern.rb
heading "Fictitious logos (identity-idp-config; the local fixture uses generic.svg)"
if [ -n "${IDP_CONFIG_DIR:-}" ] && [ -d "$IDP_CONFIG_DIR" ]; then
  (cd "$IDP_CONFIG_DIR" && for f in mybenefits-assistant housing-assistance-records retirement-benefits-portal; do exists "public/assets/images/sp-logos/$f.svg"; done)
  hits "$IDP_CONFIG_DIR" 'logo:|restrict_to_deploy_env' delegated_access.yml
else
  echo "  set IDP_CONFIG_DIR to an identity-idp-config checkout to list them"
fi

app_inventory() {
  local label=$1 dir=$2
  heading "$label ($dir)"
  [ -d "$dir" ] || { echo "  not found; set the variable to its worktree"; return 0; }
  echo "  hosts in .env.example / .env (localhost lines only):"
  hits "$dir" 'localhost' .env.example .env
  echo "  CORS allowed origins:"
  hits "$dir" 'CORS_ALLOWED_ORIGINS|cors_allowed_origins' config.rb resource_server_config.rb app.rb
  echo "  session cookie name:"
  hits "$dir" 'set :sessions|Rack::Session::Cookie' app.rb
  echo "  demo keys and certificates (names only):"
  (cd "$dir" && ls config/*.key config/*.crt 2>/dev/null | sed 's|^|  |') || true
  echo "  compose harness and e2e hosts:"
  hits "$dir" 'network_mode|localhost:(3000|9292|9393|4567)' docker-compose.e2e.yml
  hits "$dir" "ENV.fetch\\('E2E_(IDP_URL|SP_URL|RS_URL|SAML_RS_URL|USER_EMAIL)'" spec/e2e/e2e_helper.rb
}
app_inventory "identity-sts-sinatra (SP_DIR)" "${SP_DIR:-}"
app_inventory "identity-oidc-sinatra (OIDC_AGENCY_DIR)" "${OIDC_AGENCY_DIR:-}"
app_inventory "identity-saml-sinatra (SAML_AGENCY_DIR)" "${SAML_AGENCY_DIR:-}"
