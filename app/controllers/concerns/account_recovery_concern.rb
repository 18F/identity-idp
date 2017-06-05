module AccountRecoveryConcern
  extend ActiveSupport::Concern

  def confirm_password_reset_profile
    return if current_user.decorate.password_reset_profile
    redirect_to root_url
  end
end
