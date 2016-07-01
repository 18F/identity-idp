class UpdateUserProfileForm
  include ActiveModel::Model
  include FormEmailValidator
  include FormMobileValidator
  include FormPasswordValidator

  attr_accessor :mobile, :email, :current_password, :password

  validates :current_password, presence: true

  validate :verify_current_password

  def persisted?
    true
  end

  def initialize(user)
    @user = user
    self.mobile = @user.mobile
    self.email = @user.email
  end

  def submit(params)
    set_attributes(params)

    if valid_form?
      @user.update_with_password(params.merge!(mobile: mobile))
    else
      process_errors(params)
    end
  end

  def valid_form?
    valid? && !attribute_taken?
  end

  def mobile_taken?
    @mobile_taken == true
  end

  private

  def set_attributes(params)
    formatted_mobile = params[:mobile].phony_formatted(
      format: :international, normalize: :US, spaces: ' '
    )

    self.mobile = formatted_mobile if formatted_mobile != @user.mobile
    self.email = params[:email]
    self.current_password = params[:current_password]
    self.password = params[:password]
  end

  def attribute_taken?
    @mobile_taken == true || @email_taken == true
  end

  def email_taken?
    @email_taken == true
  end

  def process_errors(params)
    # To prevent discovery of existing emails and phone numbers, we check
    # to see if the only errors are "already taken" errors, and if so, we
    # act as if the user update was successful.
    if attribute_taken? && valid?
      @user.skip_confirmation_notification! if email_taken?
      send_notifications
      @user.update_with_password(params.merge!(mobile: mobile))
      return true
    end

    false
  end

  def verify_current_password
    return if @user.valid_password?(current_password) || current_password.blank?

    errors.add(:current_password, :invalid)
  end

  def send_notifications
    UserMailer.signup_with_your_email(email).deliver_later if email_taken?
    SmsSenderExistingMobileJob.perform_later(mobile) if mobile_taken?
  end
end
