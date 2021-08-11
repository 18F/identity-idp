class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to shards: {
    default: { writing: :primary, reading: :primary },
    read_replica: {
      # writing to the read_replica won't work, but AR needs to have something here
      writing: :read_replica,
      reading: :read_replica,
    },
  }
end
