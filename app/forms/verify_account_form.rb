class VerifyAccountForm
  include ActiveModel::Model

  validates :otp, presence: true
  validate :validate_otp
  validate :validate_otp_not_expired
  validate :validate_pending_profile

  attr_accessor :otp, :pii_attributes
  attr_reader :user

  def initialize(user:, otp: nil)
    @user = user
    @otp = otp
  end

  def submit
    result = valid?
    if result
      activate_profile
    else
      reset_sensitive_fields
    end
    FormResponse.new(
      success: result,
      errors: errors,
      extra: {
        pii_like_keypaths: [[:errors, :otp], [:error_details, :otp]],
      },
    )
  end

  protected

  def pending_profile
    @_pending_profile ||= user.decorate.pending_profile
  end

  def gpo_confirmation_code
    return if otp.blank? || pending_profile.blank?

    pending_profile.gpo_confirmation_codes.first_with_otp(otp)
  end

  def validate_otp_not_expired
    return unless gpo_confirmation_code.present? && gpo_confirmation_code.expired?

    errors.add :otp, :gpo_otp_expired
  end

  def validate_pending_profile
    errors.add :base, :no_pending_profile unless pending_profile
  end

  def validate_otp
    return if otp.blank? || valid_otp?
    errors.add :otp, :confirmation_code_incorrect
  end

  def valid_otp?
    otp.present? && gpo_confirmation_code.present?
  end

  def reset_sensitive_fields
    self.otp = nil
  end

  def activate_profile
    Idv::ProfileActivator.new(user: user).call
  end
end
