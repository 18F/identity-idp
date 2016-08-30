class UpdateUserPasswordForm
  include ActiveModel::Model
  include FormPasswordValidator

  validates :current_password, presence: true
  validate :verify_current_password

  def initialize(user)
    @user = user
  end

  def submit(params)
    self.password = params[:password]
    self.current_password = params[:current_password]

    @success = valid? && user.update_with_password(params)

    result
  end

  private

  attr_reader :user, :success

  attr_accessor :password, :current_password

  def verify_current_password
    return if user.valid_password?(current_password)

    errors.add(:current_password, I18n.t('errors.incorrect_password'))
  end

  def result
    {
      success?: success,
      errors: errors.full_messages
    }
  end
end
