class SetupPresenter
  attr_reader :current_user, :user_fully_authenticated, :user_opted_remember_device_cookie

  def initialize(current_user:, user_fully_authenticated:, user_opted_remember_device_cookie:,
                 opt_out_rem_me:)
    @current_user = current_user
    @user_fully_authenticated = user_fully_authenticated
    @user_opted_remember_device_cookie = user_opted_remember_device_cookie
    @opt_out_rem_me = opt_out_rem_me
  end

  def step
    no_factors_enabled? ? '3' : '4'
  end

  def steps_visible?
    SignUpProgressPolicy.new(
      @current_user,
      @user_fully_authenticated,
    ).sign_up_progress_visible?
  end

  def remember_device_box_checked?
    return false if @opt_out_rem_me
    return true if user_opted_remember_device_cookie.nil?
    ActiveModel::Type::Boolean.new.cast(user_opted_remember_device_cookie)
  end

  private

  def no_factors_enabled?
    MfaPolicy.new(@current_user).no_factors_enabled?
  end
end
