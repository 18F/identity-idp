# rubocop:disable Rails/ApplicationRecord
class SupportServiceApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { writing: :support_services, reading: :support_services }
end
# rubocop:enable Rails/ApplicationRecord
