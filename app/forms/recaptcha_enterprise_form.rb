# frozen_string_literal: true

class RecaptchaEnterpriseForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

  EXEMPT_RESULT_REASONS = ['LOW_CONFIDENCE_SCORE'].freeze

  attr_reader :recaptcha_action,
              :recaptcha_token,
              :score_threshold,
              :analytics,
              :extra_analytics_properties,
              :user_agent,
              :user_ip_address

  validate :validate_token_exists
  validate :validate_recaptcha_result

  def initialize(
    recaptcha_action: nil,
    score_threshold: 0.0,
    analytics: nil,
    extra_analytics_properties: {},
    user_agent: nil,
    user_ip_address: nil
  )
    @score_threshold = score_threshold
    @analytics = analytics
    @recaptcha_action = recaptcha_action
    @extra_analytics_properties = extra_analytics_properties
    @user_agent = user_agent
    @user_ip_address = user_ip_address
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

  def recaptcha_result
    RecaptchaService.new.create_assessment(
      recaptcha_token:,
      recaptcha_action:,
      user_agent:,
      user_ip_address:,
    )
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
