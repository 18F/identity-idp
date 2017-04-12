class VerifyProfileForm
  include ActiveModel::Model

  validates :otp, presence: true
  validate :validate_otp
  validate :validate_pending_profile

  attr_accessor :otp, :pii_attributes
  attr_reader :user

  def initialize(user:, otp: nil, pii_attributes: nil)
    @user = user
    @otp = otp
    @pii_attributes = pii_attributes
  end

  def submit
    if valid?
      activate_profile
      true
    else
      clear_fields
      false
    end
  end

  protected

  def pending_profile
    @_pending_profile ||= user.decorate.pending_profile
  end

  def validate_pending_profile
    errors.add :base, :no_pending_profile unless pending_profile
  end

  def validate_otp
    return if valid_otp?
    errors.add :otp, :otp_incorrect
  end

  def valid_otp?
    ActiveSupport::SecurityUtils.secure_compare(otp, pii_attributes.otp.to_s)
  end

  # Reset sensitive fields so they don't get sent back to the browser
  def clear_fields
    self.otp = nil
  end

  def activate_profile
    pending_profile.activate
  end
end
