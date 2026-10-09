# frozen_string_literal: true

# An agency may give one of its API URLs a shorter refresh family lifetime than the default
# (`token_exchange_refresh_token_ttl_seconds`), for example for an API that makes changes, so a
# service provider's unattended access to that API ends sooner. The effective lifetime is the
# lowest of the default, this column and the service provider's own limit; the column can never
# lengthen it. Null means the default applies.
class AddMaxFamilySecondsToTokenExchangeResourceServers < ActiveRecord::Migration[8.1]
  def change
    add_column :token_exchange_resource_servers, :max_family_seconds, :integer,
               comment: 'sensitive=false'
  end
end
