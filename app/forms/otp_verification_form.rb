class OtpVerificationForm
  include ActiveModel::Model

  validates :code, presence: true
  validate :validate_code_matches_format
  validate :validate_user_otp_presence
  validate :validate_user_otp_expiration
  validate :validate_code_equals_user_otp

  def initialize(user, code)
    @user = user
    @code = code
  end

  def submit
    success = valid?

    user.clear_direct_otp

    FormResponse.new(
      success: success,
      errors: ErrorDetails.new(errors.details).flatten,
      extra: extra_analytics_attributes,
    )
  end

  private

  attr_reader :code, :user

  def validate_code_matches_format
    return if code.match?(pattern_matching_otp_code_format)
    errors.add(:code, :code_pattern_mismatch, type: :code_pattern_mismatch)
  end

  def validate_user_otp_presence
    return if user.direct_otp.present?
    errors.add(:code, :user_otp_missing, type: :user_otp_missing)
  end

  def validate_user_otp_expiration
    return if !otp_expired?
    errors.add(:code, :user_otp_expired, type: :user_otp_expired)
  end

  def validate_code_equals_user_otp
    return if user.direct_otp == Base32::Crockford.normalize(code)
    errors.add(:code, :incorrect_code, type: :incorrect_code)
  end

  def pattern_matching_otp_code_format
    /\A[0-9]{#{otp_code_length}}\z/i
  end

  def otp_code_length
    TwoFactorAuthenticatable::DIRECT_OTP_LENGTH
  end

  def otp_expired?
    return if user.direct_otp.blank?
    Time.zone.now > user.direct_otp_sent_at + TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_SECONDS
  end

  def extra_analytics_attributes
    {
      multi_factor_auth_method: 'otp_code',
    }
  end
end
