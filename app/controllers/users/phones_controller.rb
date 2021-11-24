module Users
  class PhonesController < ReauthnRequiredController
    include PhoneConfirmation

    before_action :confirm_two_factor_authenticated
    before_action :redirect_if_phone_vendor_outage

    def add
      user_session[:phone_id] = nil
      @new_phone_form = NewPhoneForm.new(current_user)
    end

    def create
      @new_phone_form = NewPhoneForm.new(current_user)
      if @new_phone_form.submit(user_params).success?
        confirm_phone
        bypass_sign_in current_user
      else
        render :add
      end
    end

    private

    def redirect_if_phone_vendor_outage
      return unless VendorStatus.new.all_phone_vendor_outage?
      redirect_to vendor_outage_path(from: :users_phones)
    end

    def user_params
      params.require(:new_phone_form).permit(
        :phone, :international_code,
        :otp_delivery_preference,
        :otp_make_default_number
      )
    end

    def already_has_phone?
      @user_has_phone ||= @new_phone_form.already_has_phone?
    end

    def confirm_phone
      flash[:info] = t('devise.registrations.phone_update_needs_confirmation')
      prompt_to_confirm_phone(
        id: user_session[:phone_id], phone: @new_phone_form.phone,
        selected_delivery_method: @new_phone_form.otp_delivery_preference,
        selected_default_number: @new_phone_form.otp_make_default_number
      )
    end
  end
end
