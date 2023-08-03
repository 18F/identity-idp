class GpoVerifyForm
  include ActiveModel::Model

  validates :otp, presence: true
  validate :validate_otp
  validate :validate_otp_not_expired
  validate :validate_pending_profile

  attr_accessor :otp, :pii, :pii_attributes
  attr_reader :user

  def initialize(user:, pii:, otp: nil)
    @user = user
    @pii = pii
    @otp = otp
  end

  def submit
    result = valid?
    fraud_check_failed = pending_profile&.fraud_pending_reason.present?

    if result
      pending_profile&.remove_gpo_deactivation_reason
      if pending_profile&.pending_in_person_enrollment?
        # note: pending_profile is not active here
        pending_profile&.deactivate_for_in_person_verification_and_schedule_enrollment(pii)
      elsif fraud_check_failed && threatmetrix_enabled?
        pending_profile&.deactivate_for_fraud_review
      elsif fraud_check_failed
        pending_profile&.activate_after_fraud_review_unnecessary
      else
        activate_profile
      end
    else
      reset_sensitive_fields
    end
    FormResponse.new(
      success: result,
      errors: errors,
      extra: {
        enqueued_at: gpo_confirmation_code&.code_sent_at,
        which_letter: which_letter,
        letter_count: letter_count,
        attempts: attempts,
        pii_like_keypaths: [[:errors, :otp], [:error_details, :otp]],
        pending_in_person_enrollment: pending_profile&.pending_in_person_enrollment?,
        fraud_check_failed: fraud_check_failed,
      },
    )
  end

  private

  def pending_profile
    @pending_profile ||= user.pending_profile
  end

  def gpo_confirmation_code
    return if otp.blank? || pending_profile.blank?

    pending_profile.gpo_confirmation_codes.first_with_otp(otp)
  end

  def which_letter
    return if !valid_otp?
    successful_code_sent_at = gpo_confirmation_code.code_sent_at
    gpo_codes = pending_profile.gpo_confirmation_codes.sort_by(&:code_sent_at)
    position = gpo_codes.find_index { |code| code.code_sent_at == successful_code_sent_at }
    position + 1
  end

  def letter_count
    return if !valid_otp?

    pending_profile.gpo_confirmation_codes.count
  end

  def attempts
    RateLimiter.new(user: user, rate_limit_type: :verify_gpo_key).attempts
  end

  def validate_otp_not_expired
    return unless gpo_confirmation_code.present? && gpo_confirmation_code.expired?

    errors.add :otp, :gpo_otp_expired, type: :gpo_otp_expired
  end

  def validate_pending_profile
    errors.add :base, :no_pending_profile, type: :no_pending_profile unless pending_profile
  end

  def validate_otp
    return if otp.blank? || valid_otp?
    errors.add :otp, :confirmation_code_incorrect, type: :confirmation_code_incorrect
  end

  def valid_otp?
    otp.present? && gpo_confirmation_code.present?
  end

  def reset_sensitive_fields
    self.otp = nil
  end

  def threatmetrix_enabled?
    FeatureManagement.proofing_device_profiling_decisioning_enabled?
  end

  def fraud_review_checker
    @fraud_review_checker ||= FraudReviewChecker.new(user)
  end

  def activate_profile
    pending_profile&.remove_gpo_deactivation_reason
    pending_profile&.activate
  end
end
