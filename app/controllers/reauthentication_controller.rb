class ReauthenticationController < ApplicationController
  before_action :confirm_two_factor_authenticated

  def create
    user_session[:stored_location] = account_url
    user_session[:context] = 'reauthentication'

    redirect_to login_two_factor_options_path(reauthn: true)
  end
end
