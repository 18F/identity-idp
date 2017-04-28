module Users
  class ReactivateProfileController < ApplicationController
    def index
      @reactivate_profile_form = ReactivateProfileForm.new(current_user)
    end

    def create
      @reactivate_profile_form = build_reactivate_profile_form
      if @reactivate_profile_form.submit(flash)
        redirect_to account_path
      else
        render :index
      end
    end

    protected

    def build_reactivate_profile_form
      ReactivateProfileForm.new(
        current_user,
        params[:reactivate_profile_form].permit(:password, :personal_key)
      )
    end
  end
end
