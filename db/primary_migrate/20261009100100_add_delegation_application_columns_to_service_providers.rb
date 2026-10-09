# frozen_string_literal: true

# An "application" is the unit of delegated-access consent: an agency-owned service provider
# record that a service provider may be allowed to act at on the user's behalf. This migration
# turns a service provider row into something that can be such an application:
#
# * `delegation_application` marks the row as registered for delegation.
# * `delegation_scope_value` is the value a service provider puts after `token_exchange:` in its
#   authorization request to ask for this application (one scope per application).
# * The `delegation_*` content columns hold what the agency says about the application on the
#   consent screen: display name, what it lets the service do, what data it provides, whether it
#   is read-only or can make changes, and where to learn more. Localized columns are jsonb keyed
#   by locale and are rendered as escaped text, never HTML.
# * `consent_content_version` / `consent_material_version` work exactly as on `agencies`: every
#   edit bumps the first; an edit the editor marks as material also sets the second, and only a
#   material change makes remembered approvals stale.
# * `consent_approved_at` / `consent_approved_by` record Login.gov's approval of the content.
# * `allowed_delegation_service_providers` lists the service providers (by issuer) this
#   application accepts delegation from. An empty list means any service provider Login.gov has
#   approved for delegation, so an agency that does not care needs no configuration.
#
# The application's API URLs live in `token_exchange_resource_servers` (next migration).
#
# `allowed_token_exchange_brokers` from the previous design is removed rather than renamed: its
# semantics change (empty now means "any approved service provider") and the branch keeps nothing
# for compatibility because it has never run in production.
class AddDelegationApplicationColumnsToServiceProviders < ActiveRecord::Migration[8.1]
  # The unique index is built concurrently, which cannot run inside a transaction.
  disable_ddl_transaction!

  def change
    add_column :service_providers, :delegation_application, :boolean, default: false, null: false,
                                                                      comment: 'sensitive=false'
    add_column :service_providers, :delegation_scope_value, :string, comment: 'sensitive=false'
    add_column :service_providers, :delegation_display_name, :jsonb, default: {}, null: false,
                                                                     comment: 'sensitive=false'
    add_column :service_providers, :delegation_description, :jsonb, default: {}, null: false,
                                                                    comment: 'sensitive=false'
    add_column :service_providers, :delegation_data_provided, :jsonb, default: {}, null: false,
                                                                      comment: 'sensitive=false'
    add_column :service_providers, :delegation_access_type, :string, default: 'read', null: false,
                                                                     comment: 'sensitive=false'
    add_column :service_providers, :delegation_learn_more_url, :text, comment: 'sensitive=false'
    add_column :service_providers, :consent_content_version, :integer, default: 1, null: false,
                                                                       comment: 'sensitive=false'
    add_column :service_providers, :consent_material_version, :integer, default: 1, null: false,
                                                                        comment: 'sensitive=false'
    add_column :service_providers, :consent_approved_at, :datetime, comment: 'sensitive=false'
    add_column :service_providers, :consent_approved_by, :string, comment: 'sensitive=false'
    add_column :service_providers, :allowed_delegation_service_providers, :string,
               array: true, default: [], null: false, comment: 'sensitive=false'

    # One scope value identifies exactly one application; rows that are not applications leave
    # it null, which the partial index excludes.
    add_index :service_providers, :delegation_scope_value,
              unique: true, algorithm: :concurrently,
              where: 'delegation_scope_value IS NOT NULL'

    # The code that read this column is replaced in the same change, so removing it is safe.
    safety_assured do
      remove_column :service_providers, :allowed_token_exchange_brokers, :string,
                    array: true, default: [], comment: 'sensitive=false'
    end
  end
end
