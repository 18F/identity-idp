module Idv
  class PhoneController < StepController
    helper_method :idv_phone_form

    def new
    end

    def create
      if idv_phone_form.submit(phone_params)
        redirect_to idv_review_url
        self.idv_params = idv_phone_form.idv_params
      else
        render :new
      end
    end

    private

    def idv_phone_form
      @_idv_phone_form ||= Idv::PhoneForm.new(idv_params, current_user)
    end

    def phone_params
      params.require(:idv_phone_form).permit(:phone)
    end
  end
end
