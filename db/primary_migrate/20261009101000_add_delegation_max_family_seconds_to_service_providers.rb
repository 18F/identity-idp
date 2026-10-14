# frozen_string_literal: true

# Login.gov may give one service provider a shorter refresh family lifetime than the default
# (`token_exchange_refresh_token_ttl_seconds`), so that service provider's unattended delegated
# access ends sooner at every API. The effective lifetime is the lowest of the default, the API's
# own limit and this column; the column can never lengthen it. Null means the default applies.
class AddDelegationMaxFamilySecondsToServiceProviders < ActiveRecord::Migration[8.1]
  def change
    add_column :service_providers, :delegation_max_family_seconds, :integer,
               comment: 'sensitive=false'
  end
end
