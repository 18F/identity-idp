# frozen_string_literal: true

class RecaptchaEnterpriseValidator < RecaptchaValidator
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

  def recaptcha_result(recaptcha_token)
    response = faraday.post(
      assessment_url,
      {
        event: {
          token: recaptcha_token,
          siteKey: recaptcha_site_key,
          expectedAction: recaptcha_action,
        },
      },
    ) do |request|
      request.options.context = { service_name: 'recaptcha' }
    end

    if response.body['error'].present?
      RecaptchaResult.new(success: false, errors: [response.body.dig('error', 'status')].compact)
    else
      RecaptchaResult.new(
        success: response.body.dig('tokenProperties', 'valid') == true &&
          response.body.dig('tokenProperties', 'action') == recaptcha_action,
        score: response.body.dig('riskAnalysis', 'score'),
        reasons: [
          *response.body.dig('riskAnalysis', 'reasons').to_a,
          response.body.dig('tokenProperties', 'invalidReason'),
        ].compact,
      )
    end
  end

  def faraday
    Faraday.new do |conn|
      conn.request :instrumentation, name: 'request_log.faraday'
      conn.request :json
      conn.response :json
    end
  end

  def recaptcha_site_key
    case recaptcha_version
    when 2
      IdentityConfig.store.recaptcha_site_key_v2
    when 3
      IdentityConfig.store.recaptcha_site_key_v3
    end
  end
end
