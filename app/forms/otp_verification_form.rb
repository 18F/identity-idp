# frozen_string_literal: true

class OtpVerificationForm
  include ActiveModel::Model

  CODE_REGEX = /\A[0-9]+\z/
  validates :code, presence: true, length: { is: TwoFactorAuthenticatable::DIRECT_OTP_LENGTH }
  validate :validate_code_matches_format

  # @param user [User]
  # @param code [String, nil] the code the person entered
  # @param phone_configuration [PhoneConfiguration, nil] the configured phone being used, when
  #   authenticating with one that is already confirmed
  # @param phone [String, nil] the number the code must have been delivered to: the number being
  #   confirmed, or the configured phone's number when authenticating
  def initialize(user, code, phone_configuration, phone:)
    @user = user
    @code = code
    @phone_configuration = phone_configuration
    @phone = phone
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
        elsif !user.direct_otp_sent_to?(phone)
          # The code was delivered to a different number than the one this request is about, so
          # possession of that number has not been shown.
          errors.add(:code, 'user_otp_phone_mismatch', type: :user_otp_phone_mismatch)
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

  attr_reader :code, :user, :phone_configuration, :phone

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
