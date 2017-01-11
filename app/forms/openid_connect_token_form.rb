class OpenidConnectTokenForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper
  include Rails.application.routes.url_helpers

  attr_reader :grant_type,
              :code,
              :client_assertion_type,
              :client_assertion

  CLIENT_ASSERTION_TYPE = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'.freeze

  validates_inclusion_of :grant_type, in: %w(authorization_code)
  validates_inclusion_of :client_assertion_type,
                         in: [CLIENT_ASSERTION_TYPE]

  validate :validate_code
  validate :validate_client_assertion

  def initialize(params)
    %i(grant_type code client_assertion_type client_assertion).each do |key|
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
      { id_token: IdTokenBuilder.new(identity).id_token }
    else
      { error: errors.to_a.join(' ') }
    end
  end

  private

  attr_reader :identity

  def validate_code
    errors.add :code, t('openid_connect.token.errors.invalid_code') unless identity.present?
  end

  def validate_client_assertion
    return unless identity.present?

    service_provider = ServiceProvider.new(client_id)

    JWT.decode(client_assertion, service_provider.ssl_cert.public_key, true,
               algorithm: 'RS256',
               iss: client_id, verify_iss: true,
               sub: client_id, verify_sub: true,
               aud: openid_connect_token_url, verify_aud: true)
  rescue JWT::DecodeError => err
    # TODO: i18n these JWT gem error messages
    errors.add(:client_assertion, err.message)
  end

  def client_id
    identity.try(:service_provider)
  end
end
