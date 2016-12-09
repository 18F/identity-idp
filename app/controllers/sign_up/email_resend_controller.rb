module SignUp
  class EmailResendController < ApplicationController
    include ValidEmailParameter
    include UnconfirmedUserConcern

    def new
      @user = User.new
    end

    def create
      User.send_confirmation_instructions(user_params)
      flash[:notice] = t('devise.confirmations.send_paranoid_instructions')
      redirect_to root_path
    end

    private

    def user_params
      params.fetch(:user, {})
    end
  end
end
