class ReactivateAccountController < ApplicationController
  include AccountRecoveryConcern

  before_action :confirm_two_factor_authenticated
  before_action :confirm_password_reset_profile

  def index
    user_session[:acknowledge_personal_key] ||= true
  end

  def update
    user_session.delete(:acknowledge_personal_key)
    redirect_to verify_url
  end
end
