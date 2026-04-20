# frozen_string_literal: true

class RecaptchaEnterpriseForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

  BASE_VERIFICATION_ENDPOINT = 'https://recaptchaenterprise.googleapis.com/v1/projects'
  EXEMPT_RESULT_REASONS = ['LOW_CONFIDENCE_SCORE'].freeze

  attr_reader :recaptcha_action,
              :recaptcha_token,
              :score_threshold,
              :analytics,
              :extra_analytics_properties

  validate :validate_token_exists
  validate :validate_recaptcha_result

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

  def initialize(
    recaptcha_action: nil,
    score_threshold: 0.0,
    analytics: nil,
    extra_analytics_properties: {}
  )
    @score_threshold = score_threshold
    @analytics = analytics
    @recaptcha_action = recaptcha_action
    @extra_analytics_properties = extra_analytics_properties
  end

  def exempt?
    !score_threshold.positive?
  end

  # @return [Array(Boolean, String), Array(Boolean, nil)]
  def submit(recaptcha_token)
    @recaptcha_token = recaptcha_token
    @recaptcha_result = recaptcha_result if recaptcha_token.present? && !exempt?

    log_analytics(result: @recaptcha_result) if @recaptcha_result
    response = FormResponse.new(success: valid?, errors:)
    [response, @recaptcha_result&.assessment_id]
  rescue Faraday::Error => error
    log_analytics(error:)
    response = FormResponse.new(success: true)
    [response, nil]
  end

  private

  def validate_token_exists
    return if exempt? || recaptcha_token.present?
    errors.add(:recaptcha_token, :blank, message: t('errors.messages.invalid_recaptcha_token'))
  end

  def validate_recaptcha_result
    return if @recaptcha_result.blank? || recaptcha_result_valid?(@recaptcha_result)
    errors.add(:recaptcha_token, :invalid, message: t('errors.messages.invalid_recaptcha_token'))
  end

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
      {
        event: {
          token: recaptcha_token,
          siteKey: IdentityConfig.store.recaptcha_site_key,
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
        assessment_id: response.body.dig('name'),
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

  def log_analytics(result: nil, error: nil)
    analytics&.recaptcha_verify_result_received(
      recaptcha_result: result.to_h.presence,
      score_threshold:,
      evaluated_as_valid: recaptcha_result_valid?(result),
      exception_class: error&.class&.name,
      form_class: self.class.name,
      recaptcha_action:,
      **extra_analytics_properties,
    )
  end

  def recaptcha_result_valid?(result)
    return true if result.blank?
    return true if result_reason_exempt?(result)

    if result.success?
      result.score >= score_threshold
    else
      result.errors.present?
    end
  end

  def result_reason_exempt?(result)
    (EXEMPT_RESULT_REASONS & result.reasons).any?
  end
end
