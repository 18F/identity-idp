# frozen_string_literal: true

class OtpVerificationForm
  include ActiveModel::Model

  CODE_REGEX = /\A[0-9]+\z/
  validates :code, presence: true, length: { is: TwoFactorAuthenticatable::DIRECT_OTP_LENGTH }
  validate :validate_code_matches_format

  def initialize(user, code, phone_configuration)
    @user = user
    @code = code
    @phone_configuration = phone_configuration
  end

  def submit
    success = valid?

    if success
      user.with_lock do
        if user.direct_otp.blank?
          errors.add(:code, 'user_otp_missing', type: :user_otp_missing)
          success = false
        elsif otp_expired?
          errors.add(:code, 'user_otp_expired', type: :user_otp_expired)
          success = false
        elsif ActiveSupport::SecurityUtils.secure_compare(user.direct_otp, code)
          user.clear_direct_otp
          user.save
        else
          errors.add(:code, 'incorrect', type: :incorrect)
          success = false
        end
      end
    end

    FormResponse.new(
      success: success,
      errors: errors,
      extra: extra_analytics_attributes,
    )
  end

  private

  attr_reader :code, :user, :phone_configuration

  def validate_code_matches_format
    return if code.blank? || code.match?(CODE_REGEX)
    errors.add(:code, 'pattern_mismatch', type: :pattern_mismatch)
  end

  def otp_expired?
    user.direct_otp_sent_at.present? &&
      (user.direct_otp_sent_at + TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_SECONDS).past?
  end

  def extra_analytics_attributes
    {
      multi_factor_auth_method_created_at: phone_configuration&.created_at&.strftime('%s%L'),
    }
  end
end
