class AdminConstraint
  def matches?(request)
    user_is_admin?(request) && user_is_2fa_authenticated?(request)
  end

  private

  def user_is_admin?(request)
    request.env['warden'].user&.admin?
  end

  def user_is_2fa_authenticated?(request)
    request.env['warden'].session(:user)['need_two_factor_authentication'] == false
  end
end
