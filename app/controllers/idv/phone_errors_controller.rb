module Idv
  class PhoneErrorsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed
    before_action :confirm_idv_session_started
    before_action :confirmat_phone_confirmation_needed

    def warning

    end

    def timeout

    end

    def jobfail

    end

    def failure

    end

    private

    def confirmat_phone_confirmation_needed
      redirect_to_next_step if idv_session.user_phone_confirmation == true
    end

    def redirect_to_next_step
      if phone_confirmation_required?
        redirect_to idv_otp_delivery_method_url
      else
        redirect_to idv_review_url
      end
    end

    def phone_confirmation_required?
      idv_session.user_phone_confirmation != true
    end
  end
end
