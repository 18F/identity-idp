class UpdateUserProfileForm
  include ActiveModel::Model
  include FormEmailValidator
  include FormMobileValidator
  include FormPasswordValidator

  attr_accessor :mobile, :email, :current_password, :password, :totp_enabled
  attr_reader :user

  validates :current_password, presence: true

  validate :verify_current_password

  def persisted?
    true
  end

  def initialize(user)
    @user = user
    self.mobile = @user.mobile
    self.email = @user.email
    self.totp_enabled = @user.totp_enabled?
  end

  def submit(params)
    set_attributes(params)

    params.delete('mobile') if mobile_changed?

    if valid_form?
      @user.update_with_password(params)
    else
      process_errors(params)
    end
  end

  def valid_form?
    valid? && !email_taken?
  end

  def mobile_changed?
    @mobile_changed == true
  end

  private

  # rubocop:disable AccessorMethodName
  def set_attributes(params)
    formatted_mobile = params[:mobile].phony_formatted(
      format: :international, normalize: :US, spaces: ' '
    )

    if formatted_mobile != @user.mobile
      @mobile_changed = true
      self.mobile = formatted_mobile
    end
    self.email = params[:email]
    self.current_password = params[:current_password]
    self.password = params[:password]
  end
  # rubocop:enable AccessorMethodName

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
