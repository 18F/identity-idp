# frozen_string_literal: true

# An agency may give one of its API URLs a shorter delegated access token lifetime than the
# default (`token_exchange_access_token_ttl_seconds`), for example for an API that makes changes.
# The effective lifetime is the lower of the two; this column can never lengthen it. Null means
# the default applies.
class AddMaxAccessTokenSecondsToTokenExchangeResourceServers < ActiveRecord::Migration[8.1]
  def change
    add_column :token_exchange_resource_servers, :max_access_token_seconds, :integer,
               comment: 'sensitive=false'
  end
end
