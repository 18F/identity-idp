class UpdateUserProfileForm
  include ActiveModel::Model
  include FormEmailValidator
  include FormPhoneValidator
  include CustomFormHelpers::PhoneHelpers
  include FormPasswordValidator

  attr_accessor :phone, :phone_sms_enabled, :email, :current_password, :password, :totp_enabled
  attr_reader :user

  validates :current_password, presence: true

  validate :verify_current_password

  def persisted?
    true
  end

  def initialize(user)
    @user = user
    self.phone = @user.phone
    self.phone_sms_enabled = @user.phone_sms_enabled?
    self.email = @user.email
    self.totp_enabled = @user.totp_enabled?
  end

  def submit(params)
    assign_attributes(params)

    params.delete('phone') if phone_changed?

    if valid_form?
      @user.update_with_password(params)
    else
      process_errors(params)
    end
  end

  def valid_form?
    valid? && !email_taken?
  end

  private

  def assign_attributes(params)
    check_phone_change(params)
    check_sms_preference_change(params)

    self.email = params[:email]
    self.current_password = params[:current_password]
    self.password = params[:password]
  end

  def email_taken?
    @email_taken == true
  end

  def process_errors(params)
    # To prevent discovery of existing emails, we check to see if the only
    # error was "already taken", and if so, we act as if the user update
    # was successful.
    if email_taken? && valid?
      @user.skip_confirmation_notification!
      UserMailer.signup_with_your_email(email).deliver_later
      @user.update_with_password(params)
      return true
    end

    false
  end

  def verify_current_password
    return if @user.valid_password?(current_password) || current_password.blank?

    errors.add(:current_password, :invalid)
  end
end
