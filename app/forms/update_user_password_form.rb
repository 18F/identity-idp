class UpdateUserPasswordForm
  include ActiveModel::Model
  include FormPasswordValidator

  validates :password, presence: true

  def initialize(user)
    @user = user
  end

  def submit(params)
    self.password = params[:password]

    @success = valid? && user.update(params)

    result
  end

  private

  attr_reader :success

  def result
    {
      success: success,
      errors: errors.full_messages
    }
  end
end
