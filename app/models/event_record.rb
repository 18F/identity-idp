class EventRecord < ApplicationRecord
  self.abstract_class = true
  
  connects_to database: { writing: :events, reading: :events }
end
