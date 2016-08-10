class UpdateUserPasswordForm
  include ActiveModel::Model
  include FormPasswordValidator

  attr_accessor :password
  attr_reader :user

  def persisted?
    true
  end

  def initialize(user)
    @user = user
  end

  def submit(params)
    self.password = params[:password]

    return false unless valid?
    @user.update(params)
  end

  def mobile_changed?
    false
  end
end
