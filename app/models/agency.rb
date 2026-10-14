# frozen_string_literal: true

class Agency < ApplicationRecord
  has_many :agency_identities, dependent: :destroy
  # rubocop:disable Rails/HasManyOrHasOneDependent
  has_many :service_providers, inverse_of: :agency
  has_many :partner_accounts, class_name: 'Agreements::PartnerAccount'
  # rubocop:enable Rails/HasManyOrHasOneDependent

  include DelegationLocalizedContent
  # What the agency says about itself on the delegated-access consent screen, above the list of
  # its applications; jsonb keyed by locale.
  localized_content :delegation_description

  validates :name, presence: true
  validates :abbreviation, uniqueness: { case_sensitive: false }
end
