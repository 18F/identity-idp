# frozen_string_literal: true

# The API URLs of an application registered for delegated access (RFC 8707 resource indicators).
# Each row is one URL a service provider may name in the `resource` parameter of a token exchange;
# the delegated token is issued for exactly that URL. Several rows can belong to one application.
#
# Per row:
# * `identifier`: the URL, also the token audience and the API's client identifier when it calls
#   back to verify a token.
# * `service_provider_id`: the owning application (a `service_providers` row with
#   `delegation_application: true`).
# * `attempts_service_provider_id`: which service provider record's Attempts API credentials
#   receive fraud-signal events for delegated sessions at this API; defaults to the owner.
# * `billing_issuer`: the issuer whose partner agreement is billed for delegated use; defaults to
#   the owner's issuer.
# * `certs`: the API's public certificates, used to verify its `private_key_jwt` client
#   assertions; either a PEM string or a name resolved under `certs/sp/`.
# * `token_format`: `oauth` (opaque access token) or `saml2` (SAML assertion).
# * `dpop_required`: whether an exchange for this URL must carry a DPoP proof.
# * `active`: kill switch; an inactive URL cannot be exchanged for, refreshed or verified.
class CreateTokenExchangeResourceServers < ActiveRecord::Migration[8.1]
  def change
    create_table :token_exchange_resource_servers do |t|
      t.string :identifier, null: false, comment: 'sensitive=false'
      t.bigint :service_provider_id, null: false, comment: 'sensitive=false'
      t.bigint :attempts_service_provider_id, comment: 'sensitive=false'
      t.string :billing_issuer, comment: 'sensitive=false'
      t.string :certs, array: true, default: [], null: false, comment: 'sensitive=false'
      t.string :token_format, null: false, default: 'oauth', comment: 'sensitive=false'
      t.boolean :dpop_required, null: false, default: false, comment: 'sensitive=false'
      t.boolean :active, null: false, default: true, comment: 'sensitive=false'
      t.timestamps comment: 'sensitive=false'
      t.index :identifier, unique: true
      t.index :service_provider_id
    end
  end
end
