module Users
  class EditMobileController < ApplicationController
    include PhoneConfirmation

    before_action :confirm_two_factor_authenticated

    def edit
      @update_user_mobile_form = UpdateUserMobileForm.new(current_user)
    end

    def update
      @update_user_mobile_form = UpdateUserMobileForm.new(current_user)

      if @update_user_mobile_form.submit(user_params)
        process_updates
        bypass_sign_in current_user
      else
        render :edit
      end
    end

    private

    def user_params
      params.require(:update_user_mobile_form).permit(:mobile)
    end

    def process_updates
      if @update_user_mobile_form.mobile_changed?
        analytics.track_event('User asked to update their phone number')

        flash[:notice] = t('devise.registrations.mobile_update_needs_confirmation')
        prompt_to_confirm_mobile(@update_user_mobile_form.mobile)
      else
        redirect_to profile_url
      end
    end
  end
end
