class HelpText < ApplicationRecord
  belongs_to :service_provider

  validates :service_provider_id, uniqueness: true
end
