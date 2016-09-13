module TwoFactorAuthentication
  class RecoveryCodeController < ApplicationController
    before_action :confirm_two_factor_authenticated

    def show
      @code = RecoveryCodeGenerator.new(current_user).create
    end

    def acknowledge
      redirect_to after_sign_in_path_for(current_user)
    end
  end
end
