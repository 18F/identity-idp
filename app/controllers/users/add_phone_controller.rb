module Users
  class AddPhoneController
    include PhoneConfirmation

    before_action :confirm_two_factor_authenticated

    def new
      @add_phone_form = AddPhoneForm.new(current_user)
    end

    def create
      @add_phone_form = AddPhoneForm.new(current_user, nil)
      if @add_phone_form.submit(user_params).success?
        confirm_phone
        bypass_sign_in current_user
      else
        render :new
      end
    end

    private

    def confirm_phone
      flash[:notice] = t('devise.registrations.phone_update_needs_confirmation')
      prompt_to_confirm_phone(id: nil, phone: @add_phone_form.phone,
                              selected_delivery_method: @add_phone_form.otp_delivery_preference,
                              selected_default_number: @add_phone_form.otp_make_default_number)
    end
  end
end
