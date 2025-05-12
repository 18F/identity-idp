# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # Forces ActiveRecord to select individual columns instead of SELECT *
  self.ignored_columns = [:__fake_column__]

  connects_to shards: {
    default: { writing: :primary, reading: :primary },
    read_replica: {
      # writing to the read_replica won't work, but AR needs to have something here
      writing: :read_replica,
      reading: :read_replica,
    },
  }

  def self.table_name_prefix
    if connection.current_database == :data_warehouse
      'idp.'
    end
  end

  def self.with_data_warehouse
    connected_to(role: :data_warehouse) do
      yield
    end
  end
end
