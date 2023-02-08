# rubocop:disable Rails/ApplicationRecord
class PostgisDataApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { writing: :postgis_data, reading: :postgis_data }
end
# rubocop:enable Rails/ApplicationRecord
