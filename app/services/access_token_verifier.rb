class AccessTokenVerifier
  include ActionView::Helpers::TranslationHelper
  include ActiveModel::Model

  validate :validate_access_token

  def initialize(http_authorization_header)
    @http_authorization_header = http_authorization_header
    @identity = nil
  end

  def submit
    FormResponse.new(
      success: valid?, errors: errors, extra: {
        client_id: identity&.service_provider,
        ial: identity&.ial,
      }
    )
  end

  def identity
    valid? ? @identity : nil
  end

  private

  attr_reader :http_authorization_header

  def validate_access_token
    access_token = extract_access_token(http_authorization_header)
    load_identity(access_token) if access_token
  end

  def load_identity(access_token)
    identity = ServiceProviderIdentity.where(access_token: access_token).take

    if identity && OutOfBandSessionAccessor.new(identity.rails_session_id).ttl.positive?
      @identity = identity
    else
      errors.add(
        :access_token, t('openid_connect.user_info.errors.not_found'),
        type: :not_found
      )
    end
  end

  def extract_access_token(header)
    if header.blank?
      errors.add(
        :access_token, t('openid_connect.user_info.errors.no_authorization'),
        type: :no_authorization
      )
      return
    end

    bearer, access_token = header.split(' ', 2)
    if bearer != 'Bearer'
      errors.add(
        :access_token, t('openid_connect.user_info.errors.malformed_authorization'),
        type: :malformed_authorization
      )
      return
    end

    access_token
  end
end
