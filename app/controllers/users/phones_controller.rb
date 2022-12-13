module Users
  class PhonesController < ReauthnRequiredController
    include PhoneConfirmation

    before_action :confirm_two_factor_authenticated
    before_action :redirect_if_phone_vendor_outage
    before_action :check_max_phone_numbers_per_account, only: %i[add create]

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
        :phone,
        :international_code,
        :otp_delivery_preference,
        :otp_make_default_number,
      )
    end

    def confirm_phone
      flash[:info] = t('devise.registrations.phone_update_needs_confirmation')
      prompt_to_confirm_phone(
        id: user_session[:phone_id],
        phone: @new_phone_form.phone,
        selected_delivery_method: @new_phone_form.otp_delivery_preference,
        selected_default_number: @new_phone_form.otp_make_default_number,
      )
    end

    def check_max_phone_numbers_per_account
      max_phones_count = IdentityConfig.store.max_phone_numbers_per_account
      return if current_user.phone_configurations.count < max_phones_count
      flash[:phone_error] = t('users.phones.error_message')
      redirect_path = request.referer.match(account_two_factor_authentication_url) ?
                        account_two_factor_authentication_url(anchor: 'phones') :
                        account_url(anchor: 'phones')
      redirect_to redirect_path
    end
  end
end
