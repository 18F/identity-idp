# frozen_string_literal: true

# Stand-in form for the token endpoint when the request names a grant type Login.gov does not
# serve: one it has never heard of, or the token-exchange grant while delegated access is
# switched off. It fails with the RFC 6749 §5.2 `unsupported_grant_type` error and exposes the
# same `#submit`/`#response` surface as the other token forms so the controller needs no special
# case.
class OpenidConnectUnsupportedGrantForm
  include ActiveModel::Model

  ERROR_CODE = 'unsupported_grant_type'

  attr_reader :grant_type, :client_id

  def initialize(params = {})
    @grant_type = params[:grant_type]
    @client_id = params[:client_id]
  end

  # The response is logged under the token endpoint's event, so it carries that event's
  # attributes; none but the client identifier apply to a grant that is not served.
  def submit
    errors.add(:grant_type, ERROR_CODE, type: :unsupported_grant_type)
    FormResponse.new(
      success: false,
      errors:,
      extra: {
        client_id:,
        user_id: nil,
        code_digest: nil,
        ial: nil,
        code_verifier_present: false,
        service_provider_pkce: nil,
        integration_errors: nil,
      },
    )
  end

  def response
    {
      error: ERROR_CODE,
      error_description: I18n.t('openid_connect.token.errors.unsupported_grant_type'),
    }
  end
end
