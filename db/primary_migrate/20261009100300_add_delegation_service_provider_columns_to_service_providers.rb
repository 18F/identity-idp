# frozen_string_literal: true

# What a service provider record needs in order to request delegated access, and what the
# consent screen tells the user about it ("who is asking").
#
# * `token_exchange_enabled_sp`: Login.gov's approval of this service provider for delegation. It
#   replaces an allow-list that used to live in application configuration; approval is partner
#   configuration, reviewed and synced like every other service provider field.
# * `delegation_operator_legal_name` / `delegation_operator_type`: who operates the service
#   (`federal`, `state_local`, `contractor`, `non_government`).
# * `delegation_service_description`, `delegation_data_handling_statement`,
#   `delegation_ai_description`: localized plain text (jsonb keyed by locale) completing the
#   sentences the screen shows; rendered escaped, never HTML.
# * `delegation_uses_ai`: whether the service uses AI or automated decision-making on user data;
#   when true the screen shows the AI description.
# * `delegation_privacy_policy_url`, `delegation_terms_of_service_url`,
#   `delegation_support_contact`: where the user can read more and get help.
# * `sp_content_version` / `sp_material_version`: the same version pair as on applications and
#   agencies; a material change to what the service provider says about itself makes remembered
#   approvals for it stale.
#
# These fields are loaded from the delegated-access configuration file by `DelegatedAccessSeeder`
# in every environment; the partner Dashboard (identity-dashboard) does not have them.
class AddDelegationServiceProviderColumnsToServiceProviders < ActiveRecord::Migration[8.1]
  def change
    add_column :service_providers, :token_exchange_enabled_sp, :boolean, default: false, null: false,
                                                                         comment: 'sensitive=false'
    add_column :service_providers, :delegation_operator_legal_name, :string,
               comment: 'sensitive=false'
    add_column :service_providers, :delegation_operator_type, :string, comment: 'sensitive=false'
    add_column :service_providers, :delegation_service_description, :jsonb, default: {}, null: false,
                                                                            comment: 'sensitive=false'
    add_column :service_providers, :delegation_data_handling_statement, :jsonb,
               default: {}, null: false, comment: 'sensitive=false'
    add_column :service_providers, :delegation_privacy_policy_url, :text, comment: 'sensitive=false'
    add_column :service_providers, :delegation_terms_of_service_url, :text,
               comment: 'sensitive=false'
    add_column :service_providers, :delegation_support_contact, :text, comment: 'sensitive=false'
    add_column :service_providers, :delegation_uses_ai, :boolean, default: false, null: false,
                                                                  comment: 'sensitive=false'
    add_column :service_providers, :delegation_ai_description, :jsonb, default: {}, null: false,
                                                                       comment: 'sensitive=false'
    add_column :service_providers, :sp_content_version, :integer, default: 1, null: false,
                                                                  comment: 'sensitive=false'
    add_column :service_providers, :sp_material_version, :integer, default: 1, null: false,
                                                                   comment: 'sensitive=false'
  end
end
