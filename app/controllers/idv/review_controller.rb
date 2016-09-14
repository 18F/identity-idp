module Idv
  class ReviewController < StepController
    before_action :confirm_idv_steps_complete

    def confirm_idv_steps_complete
      redirect_to idv_finance_path unless idv_finance_complete?
      redirect_to idv_phone_path unless idv_phone_complete?
    end

    def new
      idv_params.symbolize_keys!
    end

    def create
      self.idv_applicant = applicant_from_params
      resolution = start_idv_session
      process_resolution(resolution)
    end

    private

    def process_resolution(resolution)
      if resolution.success
        init_questions_and_profile(resolution)
        redirect_on_success
      elsif idv_attempter.exceeded?
        redirect_to idv_fail_url
      else
        redirect_to idv_retry_url
      end
    end

    def idv_finance_complete?
      (idv_params.keys & Idv::FinanceForm::FINANCE_TYPES).any?
    end

    def idv_phone_complete?
      idv_params[:phone].present?
    end

    def redirect_on_success
      if phone_confirmation_required?
        user_session[:idv_unconfirmed_phone] = idv_params[:phone]
        redirect_to idv_phone_confirmation_send_path
      else
        redirect_to idv_questions_path
      end
    end

    def phone_confirmation_required?
      !idv_params[:phone_confirmed_at] || idv_params[:phone] != current_user.phone
    end

    def start_idv_session
      self.idv_applicant = applicant_from_params
      self.idv_vendor = idv_agent.vendor
      submit_applicant
    end

    def submit_applicant
      resolution = idv_agent.start(idv_applicant)
      self.idv_attempts += 1
      idv_flag_user_attempt
      resolution
    end

    def idv_agent
      @_agent ||= Proofer::Agent.new(
        vendor: pick_a_vendor,
        kbv: FeatureManagement.proofing_requires_kbv?
      )
    end

    def applicant_from_params
      app_vars = idv_params.select { |key, _value| Proofer::Applicant.method_defined?(key) }
      Proofer::Applicant.new(app_vars)
    end

    def init_questions_and_profile(resolution)
      self.idv_resolution = resolution
      self.idv_question_number = 0
      idv_profile_from_applicant(idv_applicant)
    end
  end
end
