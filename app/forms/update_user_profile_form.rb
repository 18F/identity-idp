class UpdateUserProfileForm
  include ActiveModel::Model
  include FormEmailValidator
  include FormMobileValidator

  attr_accessor :mobile, :email, :current_password, :password

  validates :current_password, presence: true

  validates :password,
            presence: true,
            length: Devise.password_length,
            confirmation: true,
            format: { with: Devise.password_regex, message: :password_format },
            if: :password_required?

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

    if valid?
      @user.update_with_password(params.merge!(mobile: mobile))
    else
      process_errors(params)
    end
  end

  private

  def set_attributes(params)
    formatted_mobile = params[:mobile].phony_formatted(
      format: :international, normalize: :US, spaces: ' ')

    self.mobile = formatted_mobile if formatted_mobile != @user.mobile
    self.email = params[:email]
    self.current_password = params[:current_password]
    self.password = params[:password]
  end

  def process_errors(params)
    updater = UserProfileUpdater.new(self)

    # To prevent discovery of existing emails and phone numbers, we check
    # to see if the only errors are "already taken" errors, and if so, we
    # act as if the user update was successful.
    if updater.attribute_already_taken_and_no_other_errors?
      @user.update_with_password(params.merge!(mobile: mobile))
      updater.send_notifications
      return true
    end

    # Since there are other errors at this point, we need to keep the
    # user on the edit profile page, and show them the errors, minus
    # the "already taken" errors to prevent discovery of existing emails
    # and phone numbers.
    if updater.attribute_already_taken?
      updater.delete_already_taken_errors
    end

    false
  end

  def password_required?
    password.present? || password_confirmation.present?
  end
end
