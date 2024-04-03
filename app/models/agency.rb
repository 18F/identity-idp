# frozen_string_literal: true

class Agency < ApplicationRecord
  has_many :agency_identities, dependent: :destroy
  # rubocop:disable Rails/HasManyOrHasOneDependent
  has_many :service_providers, inverse_of: :agency
  has_many :partner_accounts, class_name: 'Agreements::PartnerAccount'
  # rubocop:enable Rails/HasManyOrHasOneDependent

  validates :name, presence: true
  validates :abbreviation, uniqueness: { case_sensitive: false }
end
