# frozen_string_literal: true

# RFC 7009 token revocation for token exchange actors. Revoking a refresh token revokes its whole
# family, so an actor's sign-out ends every subject token the sign-in could still produce.
#
# As RFC 7009 §2.2 requires, a token the endpoint doesn't recognize is answered with success. So is
# a refresh token issued to a different client: a public client is identified, not authenticated,
# and refusing would confirm to the caller that the token exists.
class OpenidConnectTokenRevocationForm
  include ActiveModel::Model

  TOKEN_TYPE_HINTS = %w[refresh_token access_token].freeze

  attr_reader :client_id, :token, :token_type_hint

  validates :client_id, :token, presence: true
  validate :validate_actor, if: -> { client_id.present? }

  def initialize(params)
    @client_id = params[:client_id]
    @token = params[:token]
    @token_type_hint = params[:token_type_hint]
  end

  # @return [FormResponse]
  def submit
    return @submit if defined?(@submit)

    success = valid?
    revoke if success
    @submit = FormResponse.new(
      success:,
      errors:,
      extra: {
        client_id:,
        token_type_hint: (token_type_hint if TOKEN_TYPE_HINTS.include?(token_type_hint)),
        revoked: @revoked.present?,
        refresh_token_family_id: (refresh_token.family_id if @revoked),
      },
    )
  end

  def response
    return {} if submit.success?

    { error: oauth_error }
  end

  def http_status
    return :ok if submit.success?

    oauth_error == 'invalid_client' ? :unauthorized : :bad_request
  end

  private

  def validate_actor
    return if ServiceProvider.find_by(issuer: client_id)&.token_exchange_actor?

    errors.add(:client_id, :invalid)
  end

  # The hint only says where to look first (RFC 7009 §2.1); refresh tokens are the only kind
  # this endpoint revokes, so it looks there whatever the hint.
  def revoke
    return if refresh_token.blank? || refresh_token.actor_issuer != client_id

    @revoked = refresh_token.revoke_family!(reason: 'revoked_by_client').positive?
  end

  def refresh_token
    return @refresh_token if defined?(@refresh_token)

    @refresh_token = TokenExchangeRefreshToken.for_token(token)
  end

  def oauth_error
    return 'invalid_client' if errors.where(:client_id, :invalid).any?

    'invalid_request'
  end
end
