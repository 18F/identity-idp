# frozen_string_literal: true

class SamlRequestedAttributesPresenter
  ATTRIBUTE_TO_FRIENDLY_NAME_MAP = {
    email: :email,
    all_emails: :all_emails,
    locale: :locale,
    first_name: :given_name,
    last_name: :family_name,
    dob: :birthdate,
    ssn: :social_security_number,
    phone: :phone,
    address1: :address,
    address2: :address,
    city: :address,
    state: :address,
    verified_at: :verified_at,
    zipcode: :address,
  }.freeze

  def initialize(service_provider:, ial:, authn_request_attribute_bundle:)
    @service_provider = service_provider
    @ial = ial
    @authn_request_attribute_bundle = authn_request_attribute_bundle
  end

  def requested_attributes
    if identity_proofing_requested? || ialmax_requested?
      bundle.map { |attr| ATTRIBUTE_TO_FRIENDLY_NAME_MAP[attr] }.compact.uniq
    else
      attrs = [:email]
      attrs << :all_emails if bundle.include?(:all_emails)
      attrs << :locale if bundle.include?(:locale)
      attrs << :verified_at if bundle.include?(:verified_at)
      attrs
    end
  end

  private

  attr_reader :service_provider, :ial, :authn_request_attribute_bundle

  def identity_proofing_requested?
    Vot::AcrComponentValues.by_name[ial]&.requirements&.include?(
      :identity_proofing,
    )
  end

  def ialmax_requested?
    Vot::AcrComponentValues.by_name[ial]&.requirements&.include?(:ialmax)
  end

  def bundle
    @bundle ||= (
      authn_request_attribute_bundle || service_provider&.attribute_bundle || []
    ).map(&:to_sym)
  end
end
