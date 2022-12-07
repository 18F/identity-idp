class AgencyIdentity < ApplicationRecord
  belongs_to :user
  belongs_to :agency
  validates :uuid, presence: true
end

# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: agency_identities
#
#  id        :bigint           not null, primary key
#  uuid      :string           not null
#  agency_id :integer          not null
#  user_id   :integer          not null
#
# Indexes
#
#  index_agency_identities_on_user_id_and_agency_id  (user_id,agency_id) UNIQUE
#  index_agency_identities_on_uuid                   (uuid) UNIQUE
#
# rubocop:enable Layout/LineLength
