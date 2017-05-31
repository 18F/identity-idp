class PasswordForm
  include ActiveModel::Model
  include FormPasswordValidator

  def initialize(user)
    @user = user
  end

  def submit(params)
    submitted_password = params[:password]

    self.password = submitted_password

    FormResponse.new(success: valid?, errors: errors.messages, extra: extra_analytics_attributes)
  end

  private

  def extra_analytics_attributes
    {
      user_id: user.uuid,
    }
  end
end
