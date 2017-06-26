class DelegatedProofingForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

  ATTRS = %i[
    user_id
    client_id
    given_name_matches
    family_name_matches
    address_matches
    birthdate_matches
    social_security_number_matches
    phone_matches
  ]

  attr_reader(*ATTRS)

  validates :user_id, presence: true
  validates :client_id, presence: true

  validate :check_client_id_matches_user_id

  def initialize(params)
    ATTRS.each do |key|
      instance_variable_set("@#{key}", params[key])
    end
  end

  def submit
    success = valid?

    mark_profile_as_verified if success && all_attributes_match? && pending_profile_matches?

    # TODO: success of API request vs success of actually marking as verified?

    FormResponse.new(success: success, errors: errors)
  end

  private

  def check_client_id_matches_user_id
    return if identity.service_provider == service_provider.issuer

    errors.add(:user_id, 'user does not match')
  end

  def mark_profile_as_verified
    user = identity.user
    Idv::ProfileActivator.new(user: user).call if user
  end

  def all_attributes_match?
    # TODO: special-case SSN-optional for GOES (based on SP)
    given_name_matches &&
      family_name_matches &&
      address_matches &&
      birthdate_matches &&
      social_security_number_matches &&
      phone_matches
  end

  def pending_profile_matches?
    pending_profile&.delegated_proofing_issuer == service_provider.issuer
  end

  def service_provider
    @_service_provider ||= ServiceProvider.from_issuer(client_id)
  end

  def identity
    @_identity ||= Identity.find_by(uuid: user_id) || NullIdentity.new
  end

  def pending_profile
    @_pending_profile ||= identity.user.decorate.pending_profile
  end
end
