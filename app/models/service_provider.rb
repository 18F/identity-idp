require 'fingerprinter'
require 'identity_validations'

class ServiceProvider < ApplicationRecord
  belongs_to :agency

  # rubocop:disable Rails/HasManyOrHasOneDependent
  has_many :identities, inverse_of: :service_provider_record,
                        foreign_key: 'service_provider',
                        primary_key: 'issuer',
                        class_name: 'ServiceProviderIdentity'
  # rubocop:enable Rails/HasManyOrHasOneDependent
  has_many :in_person_enrollments,
           inverse_of: :service_provider,
           foreign_key: 'issuer',
           primary_key: 'issuer',
           dependent: :destroy

  # Do not define validations in this model.
  # See https://github.com/18F/identity_validations
  include IdentityValidations::ServiceProviderValidation

  scope(:active, -> { where(active: true) })
  scope(
    :with_push_notification_urls,
    -> { where.not(push_notification_url: nil).where.not(push_notification_url: '') },
  )

  def metadata
    attributes.symbolize_keys.merge(certs: ssl_certs)
  end

  # @return [Array<OpenSSL::X509::Certificate>]
  def ssl_certs
    @ssl_certs ||= Array(certs).select(&:present?).map do |cert|
      cert_content = load_cert(cert)
      OpenSSL::X509::Certificate.new(cert_content) if cert_content
    end.compact
  end

  def encrypt_responses?
    block_encryption != 'none'
  end

  def skip_encryption_allowed
    config = IdentityConfig.store.skip_encryption_allowed_list
    return false if config.blank?

    @allowed_list ||= config
    @allowed_list.include? issuer
  end

  private

  # @return [String,nil]
  def load_cert(cert)
    if cert.include?('-----BEGIN CERTIFICATE-----')
      cert
    elsif (cert_file = Rails.root.join('certs', 'sp', "#{cert}.crt")) && File.exist?(cert_file)
      File.read(cert_file)
    end
  end
end

# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: service_providers
#
#  id                                    :integer          not null, primary key
#  acs_url                               :text
#  active                                :boolean          default(FALSE), not null
#  allow_prompt_login                    :boolean          default(FALSE)
#  approved                              :boolean          default(FALSE), not null
#  assertion_consumer_logout_service_url :text
#  attribute_bundle                      :json
#  block_encryption                      :string           default("aes256-cbc"), not null
#  certs                                 :string           is an Array
#  default_aal                           :integer
#  description                           :text
#  device_profiling_enabled              :boolean          default(FALSE)
#  email_nameid_format_allowed           :boolean          default(FALSE)
#  failure_to_proof_url                  :text
#  friendly_name                         :string
#  help_text                             :jsonb
#  iaa                                   :string
#  iaa_end_date                          :date
#  iaa_start_date                        :date
#  ial                                   :integer
#  in_person_proofing_enabled            :boolean          default(FALSE)
#  irs_attempts_api_enabled              :boolean
#  issuer                                :string           not null
#  launch_date                           :date
#  logo                                  :text
#  metadata_url                          :text
#  native                                :boolean          default(FALSE), not null
#  piv_cac                               :boolean          default(FALSE)
#  piv_cac_scoped_by_email               :boolean          default(FALSE)
#  pkce                                  :boolean
#  push_notification_url                 :string
#  redirect_uris                         :string           default([]), is an Array
#  remote_logo_key                       :string
#  return_to_sp_url                      :text
#  signature                             :string
#  signed_response_message_requested     :boolean          default(FALSE)
#  sp_initiated_login_url                :text
#  use_legacy_name_id_behavior           :boolean          default(FALSE)
#  created_at                            :datetime
#  updated_at                            :datetime
#  agency_id                             :integer
#  app_id                                :string
#
# Indexes
#
#  index_service_providers_on_issuer  (issuer) UNIQUE
#
# rubocop:enable Layout/LineLength
