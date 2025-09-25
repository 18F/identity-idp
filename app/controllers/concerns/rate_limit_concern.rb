# frozen_string_literal: true

module RateLimitConcern
  extend ActiveSupport::Concern

  ALL_IDV_RATE_LIMITERS = [:idv_resolution, :idv_doc_auth, :proof_ssn].freeze

  def confirm_not_rate_limited(rate_limiters = ALL_IDV_RATE_LIMITERS, check_last_submission: false)
    exceeded_rate_limits = check_for_exceeded_rate_limits(rate_limiters)
    if exceeded_rate_limits.any? && !(check_last_submission && final_submission_passed?)
      rate_limit_redirect!(exceeded_rate_limits.first)
      return true
    end
    confirm_not_rate_limited_for_phone_and_letter_address_verification
  end

  def confirm_not_rate_limited_after_doc_auth
    rate_limiters = [:idv_resolution, :proof_ssn]
    confirm_not_rate_limited(rate_limiters)
  end

  def confirm_not_rate_limited_for_phone_address_verification
    # TODO: Attempts API PII add phone number
    if idv_attempter_rate_limited?(:proof_address)
      rate_limit_redirect!(:proof_address)
      return true
    end
  end

  private

  def final_submission_passed?
    doc_session_idv = user_session.to_h['idv']
    return false if doc_session_idv.blank?

    doc_session_uuid = doc_session_idv['document_capture_session_uuid']
    return false if doc_session_uuid.blank?

    document_capture_session = DocumentCaptureSession.find_by(uuid: doc_session_uuid)

    !!document_capture_session&.load_result&.success?
  end

  def confirm_not_rate_limited_for_phone_and_letter_address_verification
    if idv_attempter_rate_limited?(:proof_address) && gpo_verify_by_mail_policy.rate_limited?
      rate_limit_redirect!(:proof_address)
      return true
    elsif idv_attempter_rate_limited?(:proof_address) || gpo_verify_by_mail_policy.rate_limited?
      attempts_api_tracker.idv_rate_limited(limiter_type: :proof_address)
      fraud_ops_tracker.idv_rate_limited(limiter_type: :proof_address)
    end
  end

  def rate_limit_redirect!(rate_limit_type, step_name: nil)
    if idv_attempter_rate_limited?(rate_limit_type)
      analytics.rate_limit_reached(limiter_type: rate_limit_type, step_name:)
      attempts_api_tracker.idv_rate_limited(limiter_type: rate_limit_type)
      fraud_ops_tracker.idv_rate_limited(limiter_type: rate_limit_type)
      rate_limited_redirect(rate_limit_type)
      return true
    end
  end

  def rate_limited_redirect(rate_limit_type)
    case rate_limit_type
    when :idv_resolution
      redirect_to idv_session_errors_failure_url
    when :idv_doc_auth
      redirect_to idv_session_errors_rate_limited_url
    when :proof_address
      redirect_to idv_phone_errors_failure_url
    when :proof_ssn
      redirect_to idv_session_errors_ssn_failure_url
    end
  end

  def check_for_exceeded_rate_limits(rate_limit_types)
    rate_limit_types.select do |rate_limit_type|
      idv_attempter_rate_limited?(rate_limit_type)
    end
  end

  def idv_attempter_rate_limited?(rate_limit_type)
    if rate_limit_type == :proof_ssn
      return unless pii_ssn
      RateLimiter.new(
        target: Pii::Fingerprinter.fingerprint(pii_ssn),
        rate_limit_type: :proof_ssn,
      ).limited?
    else
      RateLimiter.new(
        user: idv_session_user,
        rate_limit_type: rate_limit_type,
      ).limited?
    end
  end

  def pii_ssn
    return unless defined?(idv_session) && user_session
    idv_session&.ssn
  end
end
