class UpdateUserPasswordForm
  include ActiveModel::Model
  include FormPasswordValidator

  validates :password, presence: true

  def initialize(user)
    @user = user
  end

  def submit(password)
    self.password = password
  end
end
