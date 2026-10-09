# frozen_string_literal: true

# Delegated-access approvals: one live row per (user, service provider, application), written by
# the consent screen and by the account page, which read and write the same row.
#
# The two tables dropped first hold no data this branch uses.
#
# Columns of token_exchange_grants:
# * service_provider_issuer: the service provider the user lets act for them.
# * application_service_provider_id: the agency application it may act at.
# * delegation_id: opaque identifier shared by every token issued under this approval, so an
#   agency can join tokens, fraud-signal events and billing to one consent.
# * source: where the approval was given, consent_screen or account_page.
# * consented_at / remember_until: when it was given and until when it is remembered. A null
#   remember_until means the approval is valid only for the authorization it was given in.
# * rails_session_id: the browser session of a single-authorization approval, so it can be
#   matched to that sign-in and nothing else. Marked sensitive because it is a session key.
# * agency_content_version / application_content_version / sp_content_version: the content
#   versions the person saw; the approval is current while each is at or above that owner's
#   material version.
# * proofed_in_session: whether identity verification happened in the sign-in that led here.
# * first_exchanged_at: when the first delegated token was issued under this approval.
# * revoked_at / revocation_reason: a revoked approval is kept for the record, never deleted.
class ReplaceTokenExchangeGrants < ActiveRecord::Migration[8.1]
  def up
    drop_table :token_exchange_broker_settings
    drop_table :token_exchange_grants

    create_table :token_exchange_grants do |t|
      t.bigint :user_id, null: false, comment: 'sensitive=false'
      t.string :service_provider_issuer, null: false, comment: 'sensitive=false'
      t.bigint :application_service_provider_id, null: false, comment: 'sensitive=false'
      t.string :delegation_id, null: false, comment: 'sensitive=false'
      t.string :source, null: false, comment: 'sensitive=false'
      t.datetime :consented_at, null: false, comment: 'sensitive=false'
      t.datetime :remember_until, comment: 'sensitive=false'
      t.string :rails_session_id, comment: 'sensitive=true'
      t.integer :agency_content_version, null: false, default: 1, comment: 'sensitive=false'
      t.integer :application_content_version, null: false, default: 1, comment: 'sensitive=false'
      t.integer :sp_content_version, null: false, default: 1, comment: 'sensitive=false'
      t.boolean :proofed_in_session, null: false, default: false, comment: 'sensitive=false'
      t.datetime :first_exchanged_at, comment: 'sensitive=false'
      t.datetime :revoked_at, comment: 'sensitive=false'
      t.string :revocation_reason, comment: 'sensitive=false'
      t.timestamps comment: 'sensitive=false'

      t.index :delegation_id, unique: true
      t.index :application_service_provider_id
      t.index %i[user_id service_provider_issuer application_service_provider_id],
              unique: true, where: 'revoked_at IS NULL',
              name: 'index_token_exchange_grants_live'
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
