# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # Forces ActiveRecord to select individual columns instead of SELECT *
  self.ignored_columns = [:__fake_column__]

  shards_config = {
    default: { writing: :primary, reading: :primary },
    read_replica: {
      # writing to the read_replica won't work, but AR needs to have something here
      writing: :read_replica,
      reading: :read_replica,
    },
  }

  if IdentityConfig.store.data_warehouse_enabled && IdentityConfig.store.data_warehouse_v3_enabled
    shards_config[:data_warehouse] = {
      # writing to the data_warehouse won't work, but AR needs to have something here
      writing: :data_warehouse,
      reading: :data_warehouse,
    }
  end

  connects_to shards: shards_config
end
