# frozen_string_literal: true

class RecaptchaEnterpriseForm < RecaptchaForm
  BASE_VERIFICATION_ENDPOINT = 'https://recaptchaenterprise.googleapis.com/v1/projects'

  private

  def assessment_url
    UriService.add_params(
      format(
        '%{base_endpoint}/%{project_id}/assessments',
        base_endpoint: BASE_VERIFICATION_ENDPOINT,
        project_id: IdentityConfig.store.recaptcha_enterprise_project_id,
      ),
      key: IdentityConfig.store.recaptcha_enterprise_api_key,
    )
  end

  def recaptcha_result
    response = faraday.post(
      assessment_url,
      { event: assessment_properties },
    ) do |request|
      request.options.context = { service_name: 'recaptcha' }
    end

    if response.body['error'].present?
      RecaptchaResult.new(success: false, errors: [response.body.dig('error', 'status')].compact)
    else
      RecaptchaResult.new(
        success: response.body.dig('tokenProperties', 'valid') == true &&
          response.body.dig('tokenProperties', 'action') == recaptcha_action,
        assessment_id: response.body.dig('name'),
        score: response.body.dig('riskAnalysis', 'score'),
        reasons: [
          *response.body.dig('riskAnalysis', 'reasons').to_a,
          response.body.dig('tokenProperties', 'invalidReason'),
        ].compact,
        account_defender_assesment: response.body.dig('accountDefenderAssessment'),
      )
    end
  end

  def assessment_properties
    {
      token: recaptcha_token,
      siteKey: IdentityConfig.store.recaptcha_site_key,
      expectedAction: recaptcha_action,
    }.merge(user_info)
  end

  def user_info
    return {} unless IdentityConfig.store.account_defender_enabled
    {
      userInfo: {
        accountId: user&.uuid,
        userIds: {
          email: email_fingerprint,
        },
      },
    }
  end

  def encrypted_email
    email = user.email_addresses.first&.email
    Digest::SHA256.hexdigest(email)
  end

  def faraday
    Faraday.new do |conn|
      conn.request :instrumentation, name: 'request_log.faraday'
      conn.request :json
      conn.response :json
    end
  end
end
