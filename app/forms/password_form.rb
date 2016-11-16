class PasswordForm
  include ActiveModel::Model
  include FormPasswordValidator

  def initialize(user)
    @user = user
  end

  def submit(params)
    submitted_password = params[:password]

    self.password = submitted_password

    @success = valid?

    result
  end

  private

  attr_reader :success

  def result
    {
      success: success,
      errors: errors.messages.values.flatten,
      user_id: user.uuid
    }
  end
end
