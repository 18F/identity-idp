class AgencyIdentity < ApplicationRecord
  belongs_to :user
  belongs_to :agency
  validates :uuid, presence: true

  def agency_enabled?
    !FeatureManagement.agencies_with_agency_based_uuids.index(agency_id).nil?
  end
end
