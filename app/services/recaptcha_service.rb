# frozen_string_literal: true

class RecaptchaService
  attr_reader :recaptcha_client

  RecaptchaResult = Struct.new(
    :success,
    :assessment_id,
    :score,
    :errors,
    :reasons,
    keyword_init: true,
  ) do
    alias_method :success?, :success

    def initialize(success:, assessment_id: nil, score: nil, errors: [], reasons: [])
      super
    end
  end

  def initialize
    credentials = Google::Auth::APIKeyCredentials.make_creds(
      api_key: IdentityConfig.store.recaptcha_enterprise_api_key,
    )

    timeout = IdentityConfig.store.recaptcha_request_timeout_in_seconds

    @recaptcha_client = Google::Cloud::RecaptchaEnterprise.recaptcha_enterprise_service do |config|
      config.credentials = credentials
      config.rpcs.create_assessment.timeout = timeout
      config.rpcs.annotate_assessment.timeout = timeout
    end
  end

  def create_assessment(recaptcha_token:, recaptcha_action:, user_agent: nil, user_ip_address: nil)
    event = {
      site_key: IdentityConfig.store.recaptcha_site_key,
      token: recaptcha_token,
    }
    if FeatureManagement.recaptcha_enterprise_additional_context_enabled?
      event[:user_agent] = user_agent if user_agent.present?
      event[:user_ip_address] = user_ip_address if user_ip_address.present?
    end

    request = {
      parent: "projects/#{IdentityConfig.store.recaptcha_enterprise_project_id}",
      assessment: {
        event:,
      },
    }

    response = recaptcha_client.create_assessment request
    if response.token_properties.valid
      if response.token_properties.action == recaptcha_action
        RecaptchaResult.new(
          success: true,
          assessment_id: response.name,
          score: response.risk_analysis.score,
          reasons: response.risk_analysis.reasons,
        )
      else
        RecaptchaResult.new(
          success: false,
          errors: [
            "Unexpected action #{response.token_properties.action}, expected #{recaptcha_action}",
          ],
        )
      end
    else
      RecaptchaResult.new(success: false, errors: [response.token_properties.invalid_reason])
    end
  end

  def annotate_assessment(assessment_id:, reason:, annotation:)
    request = Google::Cloud::RecaptchaEnterprise::V1::AnnotateAssessmentRequest.new(
      name: assessment_id,
      reasons: Array(reason),
      annotation:,
    )

    recaptcha_client.annotate_assessment request
  end
end
