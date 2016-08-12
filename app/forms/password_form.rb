class PasswordForm
  include ActiveModel::Model
  include FormPasswordValidator

  attr_accessor :password, :reset_password_token

  def initialize(user)
    @user = user
    self.reset_password_token = @user.reset_password_token
  end

  def submit(params)
    submitted_password = params[:password]

    self.password = submitted_password

    if valid? && user_valid?
      @user.password = submitted_password
    else
      false
    end
  end

  private

  # This is needed because @user.valid? only checks for validation errors,
  # but in this case the error would be with the reset_password_token,
  # which is added by Devise via errors.add
  def user_valid?
    @user.errors.empty?
  end
end
