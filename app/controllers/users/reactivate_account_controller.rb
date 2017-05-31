module Users
  class ReactivateAccountController < ApplicationController
    def index
      @reactivate_account_form = ReactivateAccountForm.new(current_user)
    end

    def create
      @reactivate_account_form = build_reactivate_account_form
      if @reactivate_account_form.submit(flash)
        redirect_to account_path
      else
        render :index
      end
    end

    protected

    def build_reactivate_account_form
      ReactivateAccountForm.new(
        current_user,
        params[:reactivate_account_form].permit(:password, :personal_key)
      )
    end
  end
end
