class RegisterUserEmailForm
  include ActiveModel::Model
  include FormEmailValidator

  def self.model_name
    ActiveModel::Name.new(self, nil, 'User')
  end

  delegate :email, to: :user

  def user
    @user ||= User.new
  end

  def submit(params)
    user.email = params[:email]

    if valid?
      user.save!
    else
      process_errors
    end
  end

  private

  def process_errors
    updater = UserProfileUpdater.new(self)

    # To prevent discovery of existing emails and phone numbers, we check
    # to see if the only errors are "already taken" errors, and if so, we
    # act as if the user update was successful.
    if updater.attribute_already_taken_and_no_other_errors?
      user.update(email: email)
      updater.send_notifications
      return true
    end

    false
  end
end
