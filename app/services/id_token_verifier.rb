class IdTokenVerifier
  include ActionView::Helpers::TranslationHelper
  include ActiveModel::Model
  include Rails.application.routes.url_helpers

  validate :validate_id_token

  def initialize(http_authorization_header)
    @http_authorization_header = http_authorization_header
    @identity = nil
  end

  def submit
    FormResponse.new(success: valid?, errors: errors)
  end

  def identity
    valid? ? @identity : nil
  end

  private

  attr_reader :http_authorization_header

  def validate_id_token
    id_token = extract_id_token(http_authorization_header)
    load_identity(id_token) if id_token
  end

  def load_identity(id_token)
    payload, _headers = JWT.decode(
      id_token, RequestKeyManager.private_key, true,
      algorithm: 'RS256', verify_iat: true,
      iss: root_url, verify_iss: true
    ).map(&:with_indifferent_access)

    # TODO: validate nonce as well?
    @identity = Identity.where(uuid: payload[:sub], service_provider: payload[:aud]).first!
  rescue JWT::DecodeError => err
    errors.add(:id_token, err.message)
  rescue ActiveRecord::RecordNotFound
    errors.add(:id_token, t('openid_connect.user_info.errors.not_found'))
  end

  def extract_id_token(header)
    if header.blank?
      errors.add(:id_token, t('openid_connect.user_info.errors.no_authorization'))
      return
    end

    bearer, id_token = header.split(' ', 2)
    if bearer != 'Bearer'
      errors.add(:id_token, t('openid_connect.user_info.errors.malformed_authorization'))
      return
    end

    id_token
  end
end
