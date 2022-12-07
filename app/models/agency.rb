class Agency < ApplicationRecord
  has_many :agency_identities, dependent: :destroy
  # rubocop:disable Rails/HasManyOrHasOneDependent
  has_many :service_providers, inverse_of: :agency
  has_many :partner_accounts, class_name: 'Agreements::PartnerAccount'
  # rubocop:enable Rails/HasManyOrHasOneDependent

  validates :name, presence: true
  validates :abbreviation, uniqueness: { case_sensitive: false }
end

# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: agencies
#
#  id           :bigint           not null, primary key
#  abbreviation :string
#  name         :string           not null
#
# Indexes
#
#  index_agencies_on_abbreviation  (abbreviation) UNIQUE
#  index_agencies_on_name          (name) UNIQUE
#
# rubocop:enable Layout/LineLength
