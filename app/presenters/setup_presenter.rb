class SetupPresenter
  attr_reader :current_user, :user_fully_authenticated, :user_opted_remember_device_cookie

  def initialize(
    current_user:,
    user_fully_authenticated:,
    user_opted_remember_device_cookie:,
    remember_device_default:
  )
    @current_user = current_user
    @user_fully_authenticated = user_fully_authenticated
    @user_opted_remember_device_cookie = user_opted_remember_device_cookie
    @remember_device_default = remember_device_default
  end

  def remember_device_box_checked?
    return @remember_device_default if user_opted_remember_device_cookie.nil?
    ActiveModel::Type::Boolean.new.cast(user_opted_remember_device_cookie)
  end

  private

  def no_factors_enabled?
    MfaPolicy.new(@current_user).no_factors_enabled?
  end
end
