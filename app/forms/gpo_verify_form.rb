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
    threatmetrix_check_failed = fraud_review_checker.fraud_check_failed?
    if result
      pending_profile&.remove_gpo_deactivation_reason
      if pending_in_person_enrollment?
        UspsInPersonProofing::EnrollmentHelper.schedule_in_person_enrollment(user, pii)
        pending_profile&.deactivate(:in_person_verification_pending)
      elsif fraud_review_checker.fraud_check_failed? && threatmetrix_enabled?
        bump_fraud_review_pending_timestamps
      else
        pending_profile&.update!(
          fraud_review_pending_at: nil,
          fraud_rejection_at: nil,
        )
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
        pii_like_keypaths: [[:errors, :otp], [:error_details, :otp]],
        pending_in_person_enrollment: pending_in_person_enrollment?,
        threatmetrix_check_failed: threatmetrix_check_failed,
      },
    )
  end

  protected

  def pending_profile
    @pending_profile ||= user.pending_profile
  end

  def gpo_confirmation_code
    return if otp.blank? || pending_profile.blank?

    pending_profile.gpo_confirmation_codes.first_with_otp(otp)
  end

  def bump_fraud_review_pending_timestamps
    pending_profile&.bump_fraud_review_pending_timestamps
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

  def pending_in_person_enrollment?
    pending_profile&.proofing_components&.[]('document_check') == Idp::Constants::Vendors::USPS
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
