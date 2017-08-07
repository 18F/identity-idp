module AccountReactivationConcern
  extend ActiveSupport::Concern

  def confirm_password_reset_profile
    return if current_user.decorate.password_reset_profile
    redirect_to root_url
  end

  def reactivate_account_session
    @_reactivate_account_session ||= ReactivateAccountSession.new(
      user: current_user,
      user_session: user_session
    )
  end
end
