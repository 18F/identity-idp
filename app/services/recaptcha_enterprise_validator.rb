class RecaptchaEnterpriseValidator < RecaptchaValidator
  BASE_VERIFICATION_ENDPOINT = 'https://recaptchaenterprise.googleapis.com/v1/projects'.freeze

  private

  def assessment_url
    UriService.add_params(
      "#{BASE_VERIFICATION_ENDPOINT}/#{IdentityConfig.store.recaptcha_enterprise_project_id}" \
        "/assessments",
      key: IdentityConfig.store.recaptcha_enterprise_api_key,
    )
  end

  def logged_recaptcha_result(recaptcha_result)
    recaptcha_result&.slice('tokenProperties', 'riskAnalysis', 'name', 'error')
  end

  def recaptcha_response(recaptcha_token)
    faraday.post(
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
  end

  def faraday
    Faraday.new do |conn|
      conn.request :instrumentation, name: 'request_log.faraday'
      conn.request :json
      conn.response :json
    end
  end

  def recaptcha_result_valid?(recaptcha_result)
    return true if recaptcha_result.blank? || recaptcha_result['error'].present?
    recaptcha_result['tokenProperties']['valid'] &&
      recaptcha_result['tokenProperties']['action'] == recaptcha_action &&
      recaptcha_score_meets_threshold?(recaptcha_result['riskAnalysis']['score'])
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
