module Verify
  class ReviewController < StepController
    include PhoneConfirmation

    before_action :confirm_idv_steps_complete
    before_action :confirm_current_password, only: [:create]

    helper_method :idv_params

    def confirm_idv_steps_complete
      return redirect_to(verify_session_path) unless idv_profile_complete?
      return redirect_to(verify_finance_path) unless idv_finance_complete?
      return redirect_to(verify_phone_path) unless idv_phone_complete?
    end

    def confirm_current_password
      return if valid_password?

      flash[:error] = t('idv.errors.incorrect_password')
      redirect_to verify_review_path
    end

    def new
      idv_session.params.symbolize_keys!
      analytics.track_event(Analytics::IDV_REVIEW_VISIT)
    end

    def create
      init_profile
      redirect_to_next_step
      analytics.track_event(Analytics::IDV_REVIEW_COMPLETE)
    end

    private

    def idv_profile_complete?
      idv_session.resolution.try(:success?)
    end

    def idv_finance_complete?
      idv_session.financials_confirmation.try(:success?)
    end

    def idv_phone_complete?
      idv_session.phone_confirmation.try(:success?)
    end

    def init_profile
      idv_session.cache_applicant_profile_id(idv_session.applicant)
      idv_session.cache_encrypted_pii(current_user.user_access_key)
    end

    def redirect_to_next_step
      if phone_confirmation_required?
        prompt_to_confirm_phone(phone: idv_params[:phone], otp_method: nil, context: 'idv')
      else
        redirect_to verify_confirmations_path
      end
    end

    def idv_params
      idv_session.params
    end

    def phone_confirmation_required?
      idv_params[:phone] != current_user.phone
    end

    def valid_password?
      current_user.valid_password?(password)
    end

    def password
      params.fetch(:user, {})[:password].presence
    end
  end
end
