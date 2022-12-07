class ServiceProviderIdentity < ApplicationRecord
  self.table_name = :identities

  include NonNullUuid

  belongs_to :user
  validates :service_provider, presence: true

  # rubocop:disable Rails/InverseOf
  belongs_to :service_provider_record,
             class_name: 'ServiceProvider',
             foreign_key: 'service_provider',
             primary_key: 'issuer'
  # rubocop:enable Rails/InverseOf

  scope :not_deleted, -> { where(deleted_at: nil) }

  CONSENT_EXPIRATION = 1.year

  def deactivate
    update!(session_uuid: nil)
  end

  def sp_metadata
    service_provider_record&.metadata || {}
  end

  def display_name
    sp_metadata[:friendly_name] || service_provider_record&.agency&.name || service_provider
  end

  def agency_name
    service_provider_record&.agency&.name || sp_metadata[:friendly_name] || service_provider
  end

  def piv_cac_enabled?
    TwoFactorAuthentication::PivCacPolicy.new(user).enabled?
  end

  def failure_to_proof_url
    sp_metadata[:failure_to_proof_url]
  end

  def return_to_sp_url
    sp_metadata[:return_to_sp_url]
  end

  def friendly_name
    sp_metadata[:friendly_name]
  end

  def service_provider_id
    service_provider_record&.id
  end

  def happened_at
    last_authenticated_at.in_time_zone('UTC')
  end
end

# == Schema Information
#
# Table name: identities
#
#  id                         :integer          not null, primary key
#  access_token               :string
#  code_challenge             :string
#  deleted_at                 :datetime
#  ial                        :integer          default(1)
#  last_authenticated_at      :datetime
#  last_consented_at          :datetime
#  last_ial1_authenticated_at :datetime
#  last_ial2_authenticated_at :datetime
#  nonce                      :string
#  scope                      :string
#  service_provider           :string(255)
#  session_uuid               :string(255)
#  uuid                       :string           not null
#  verified_at                :datetime
#  verified_attributes        :json
#  created_at                 :datetime
#  updated_at                 :datetime
#  rails_session_id           :string
#  user_id                    :integer
#
# Indexes
#
#  index_identities_on_access_token                  (access_token) UNIQUE
#  index_identities_on_session_uuid                  (session_uuid) UNIQUE
#  index_identities_on_user_id_and_service_provider  (user_id,service_provider) UNIQUE
#  index_identities_on_uuid                          (uuid) UNIQUE
#
