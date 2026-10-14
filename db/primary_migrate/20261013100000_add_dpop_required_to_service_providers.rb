# frozen_string_literal: true

# Whether every token Login.gov issues to this service provider is bound to a key it holds
# (RFC 9449 DPoP): the authorization code through `dpop_jkt`, the sign-in access token and, for
# delegated access, the delegated and refresh tokens. The setting takes effect only for a public
# client (`pkce` true), which has no client secret and holds its tokens in the person's browser; a
# confidential client authenticates with its registered key and keeps bearer tokens whatever the
# setting says. It is independent of approval for delegated access (`token_exchange_enabled_sp`):
# an approved public client without it receives bearer tokens throughout.
#
# Loaded from the delegated-access configuration file like the other delegated-access fields; the
# partner Dashboard (identity-dashboard) does not have it.
class AddDpopRequiredToServiceProviders < ActiveRecord::Migration[8.1]
  def change
    add_column :service_providers, :dpop_required, :boolean, null: false, default: false,
                                                             comment: 'sensitive=false'
  end
end
