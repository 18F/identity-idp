class OpenidConnectTokenForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

  attr_reader :grant_type,
              :code,
              :client_id,
              :client_secret,
              :redirect_uri

  validates_inclusion_of :grant_type, in: %w(authorization_code)

  validate :validate_code
  validate :validate_client_id
  validate :validate_client_secret
  validate :validate_redirect_uri

  def initialize(params)
    %i(grant_type code client_id client_secret redirect_uri).each do |key|
      instance_variable_set(:"@#{key}", params[key])
    end

    @identity = Identity.where(session_uuid: code).first
  end

  def submit
    {
      success: valid?,
      client_id: client_id,
      errors: errors.messages
    }
  end

  def response
    if valid?
      {
        access_token: identity.access_token,
        token_type: 'Bearer',
        expires_in: Pii::SessionStore.new(identity.session_uuid).ttl,
        id_token: IdTokenBuilder.new(identity).id_token
      }
    else
      { error: errors.to_a.join(' ') }
    end
  end

  private

  attr_reader :identity

  def validate_code
    errors.add :code, t('openid_connect.token.errors.invalid_code') unless identity.present?
  end

  def validate_client_id
    return if client_id == service_provider.issuer
    errors.add :client_id, 'bad client_id'
  end

  def validate_client_secret
    return if client_secret == service_provider.metadata[:client_secret]
    errors.add :client_secret, 'bad secret'
  end

  def validate_redirect_uri
    return if service_provider.metadata.fetch(:redirect_uri, '').start_with?(redirect_uri.to_s)
    errors.add :redirect_uri, 'nah'
  end

  def service_provider
    ServiceProvider.new(identity.try(:service_provider))
  end
end
