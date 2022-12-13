class OpenidConnectLogoutForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper
  include RedirectUriValidator

  ATTRS = %i[
    client_id
    current_user
    id_token_hint
    post_logout_redirect_uri
    state
  ].freeze

  attr_reader(*ATTRS)

  RANDOM_VALUE_MINIMUM_LENGTH = OpenidConnectAuthorizeForm::RANDOM_VALUE_MINIMUM_LENGTH

  validates :client_id,
            presence: {
              message: I18n.t('openid_connect.logout.errors.client_id_missing'),
            },
            if: :reject_id_token_hint?
  validates :id_token_hint,
            absence: {
              message: I18n.t('openid_connect.logout.errors.id_token_hint_present'),
            },
            if: :reject_id_token_hint?
  validates :post_logout_redirect_uri, presence: true
  validates :state,
            length: { minimum: RANDOM_VALUE_MINIMUM_LENGTH },
            if: -> { !state.nil? }

  validate :id_token_hint_or_client_id_present,
           if: -> { !reject_id_token_hint? }
  validate :validate_identity, unless: :reject_id_token_hint?
  validate :valid_client_id

  def initialize(params:, current_user:)
    ATTRS.each do |key|
      instance_variable_set(:"@#{key}", params[key])
    end

    @current_user = current_user
    @identity = load_identity
  end

  def submit
    @success = valid?

    identity&.deactivate if success

    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  # Used by RedirectUriValidator
  def service_provider
    return @service_provider if defined?(@service_provider)
    sp_from_client_id = ServiceProvider.find_by(issuer: client_id)

    @service_provider =
      if reject_id_token_hint?
        sp_from_client_id
      else
        identity&.service_provider_record || sp_from_client_id
      end

    @service_provider
  end

  private

  attr_reader :identity, :success

  def reject_id_token_hint?
    IdentityConfig.store.reject_id_token_hint_in_logout
  end

  def load_identity
    identity_from_client_id = current_user&.
      identities&.
      find_by(service_provider: client_id)

    if reject_id_token_hint?
      identity_from_client_id
    else
      payload, _headers = JWT.decode(
        id_token_hint,
        AppArtifacts.store.oidc_public_key,
        true,
        algorithm: 'RS256',
        leeway: Float::INFINITY,
      ).map(&:with_indifferent_access)

      identity_from_payload(payload) || identity_from_client_id
    end
  rescue JWT::DecodeError
    nil
  end

  def identity_from_payload(payload)
    uuid = payload[:sub]
    sp = payload[:aud]
    AgencyIdentityLinker.sp_identity_from_uuid_and_sp(uuid, sp)
  end

  def id_token_hint_or_client_id_present
    return if client_id.present? || id_token_hint.present?

    errors.add(
      :base,
      t('openid_connect.logout.errors.no_client_id_or_id_token_hint'),
      type: :client_id_or_id_token_hint_missing,
    )
  end

  def valid_client_id
    return unless client_id.present? && id_token_hint.blank?
    return if service_provider.present?

    errors.add(
      :client_id,
      t('openid_connect.logout.errors.client_id_invalid'),
      type: :client_id_invalid,
    )
  end

  def validate_identity
    return if client_id.present? # there won't alwasy be an identity found

    unless identity
      errors.add(
        :id_token_hint,
        t('openid_connect.logout.errors.id_token_hint'),
        type: :id_token_hint,
      )
    end
  end

  def extra_analytics_attributes
    {
      client_id_parameter_present: client_id.present?,
      id_token_hint_parameter_present: id_token_hint.present?,
      client_id: service_provider&.issuer,
      redirect_uri: redirect_uri,
      sp_initiated: true,
      oidc: true,
    }
  end

  def redirect_uri
    success ? logout_redirect_uri : error_redirect_uri
  end

  def logout_redirect_uri
    return nil if errors.include?(:redirect_uri)
    return post_logout_redirect_uri unless state.present?

    UriService.add_params(post_logout_redirect_uri, state: state)
  end

  def error_redirect_uri
    uri = post_logout_redirect_uri unless errors.include?(:redirect_uri)

    UriService.add_params(
      uri,
      error: 'invalid_request',
      error_description: errors.full_messages.join(' '),
      state: state,
    )
  end
end
