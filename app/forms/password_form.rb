class PasswordForm
  include ActiveModel::Model
  include FormPasswordValidator

  def initialize(user)
    @user = user
  end

  def submit(params)
    submitted_password = params[:password]

    self.password = submitted_password

    if valid?
      user.password = submitted_password
    else
      false
    end
  end
end
