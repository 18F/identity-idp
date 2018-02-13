class Agency < ApplicationRecord
  has_many :agency_identities, dependent: :destroy
  validates :name, presence: true
end
