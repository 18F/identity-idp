module Phones
  class EditPhoneController < ReauthnRequiredController
    before_action :confirm_two_factor_authenticated
    before_action :confirm_user_can_edit_phone

    def edit
      analytics.track_event(Analytics::PHONE_CHANGE_VIEWED)
      @edit_phone_form = EditPhoneForm.new(current_user, phone_configuration)
    end

    def update
      @edit_phone_form = EditPhoneForm.new(current_user, phone_configuration)
      result = @edit_phone_form.submit(edit_phone_params)
      analytics.track_event(Analytics::PHONE_CHANGE_SUBMITTED, result.to_h)
      if result.success?
        redirect_to account_url
      else
        render :edit
      end
    end

    private

    def confirm_user_can_edit_phone
      render_not_found if phone_configuration.nil?
      false
    end

    def phone_configuration
      @phone_configuration ||= current_user.phone_configurations.find_by(id: params[:id])
    end

    def edit_phone_params
      params.require(:edit_phone_form).permit(:delivery_preference,
                                              :make_default_number)
    end
  end
end
