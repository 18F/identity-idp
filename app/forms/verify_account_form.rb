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
    if valid?
      activate_profile
      true
    else
      reset_sensitive_fields
      false
    end
  end

  protected

  def pending_profile
    @_pending_profile ||= user.decorate.pending_profile
  end

  def usps_confirmation_code
    return if otp.blank? || pending_profile.blank?

    pending_profile.usps_confirmation_codes.first_with_otp(otp)
  end

  def validate_otp_not_expired
    return unless usps_confirmation_code.present? && usps_confirmation_code.expired?

    errors.add :otp, :usps_otp_expired
  end

  def validate_pending_profile
    errors.add :base, :no_pending_profile unless pending_profile
  end

  def validate_otp
    return if otp.blank? || valid_otp?
    errors.add :otp, :confirmation_code_incorrect
  end

  def valid_otp?
    otp.present? && usps_confirmation_code.present?
  end

  def reset_sensitive_fields
    self.otp = nil
  end

  def activate_profile
    Idv::ProfileActivator.new(user: user).call
  end
end
