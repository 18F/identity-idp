class Agency < ApplicationRecord
  has_many :agency_identities, dependent: :destroy
  # rubocop:disable Rails/HasManyOrHasOneDependent
  has_many :service_providers, inverse_of: :agency
  # rubocop:enable Rails/HasManyOrHasOneDependent
  validates :name, presence: true
end
