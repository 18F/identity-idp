module Idv
  class SessionsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated

    def index
      @using_mock_vendor = pick_a_vendor == :mock
      @profile = idv_profile_form
    end

    def create
      idv_params.merge!(profile_params)
      @profile = idv_profile_form
      submit_profile
    end

    def dupe
    end

    def finance
      prep_step
    end

    def phone
      prep_step
    end

    def review
      prep_step
    end

    def update_finance
      prep_step
      idv_params.merge!(financial_params.delete_if { |_key, value| value.blank? })
      redirect_to idv_sessions_phone_url
    end

    def update_phone
      prep_step
      idv_params['phone'] = params.require(:phone)
      if idv_params['phone'] == current_user.phone
        idv_params['phone_confirmed_at'] = current_user.phone_confirmed_at
      end
      redirect_to idv_sessions_review_url
    end

    def update_review
      self.idv_applicant = applicant_from_params
      resolution = start_idv_session
      if resolution.success
        init_questions_and_profile(resolution)
        redirect_on_success
      else
        flash[:error] = I18n.t('idv.titles.fail')
        redirect_to idv_sessions_url
      end
    end

    private

    def submit_profile
      if @profile.submit(profile_params)
        redirect_to idv_sessions_finance_url
      elsif @profile.errors.include?(:ssn)
        flash[:error] = I18n.t('idv.errors.duplicate_ssn')
        redirect_to idv_sessions_dupe_url
      else
        render :index
      end
    end

    def redirect_on_success
      if phone_confirmation_required?
        user_session[:idv_unconfirmed_phone] = idv_params['phone']
        redirect_to idv_phone_confirmation_send_path
      else
        redirect_to idv_questions_path
      end
    end

    def phone_confirmation_required?
      !idv_params['phone_confirmed_at'] || idv_params['phone'] != current_user.phone
    end

    def prep_step
      @profile = idv_profile_form
      @idv_params = idv_params
    end

    def idv_profile_form
      IdvProfileForm.new((idv_params || {}), current_user.id)
    end

    def start_idv_session
      agent = Proofer::Agent.new(
        vendor: pick_a_vendor,
        kbv: FeatureManagement.proofing_requires_kbv?
      )
      self.idv_applicant = applicant_from_params
      self.idv_vendor = agent.vendor
      agent.start(idv_applicant)
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

    def profile_params
      params.require(:profile).permit(:first_name, :last_name, :dob, :ssn, :address1, :address2,
                                      :city, :state, :zipcode)
    end

    def financial_params
      params.slice(:ccn, :mortgage, :home_equity_line, :auto_loan, :bank_routing, :bank_acct)
    end

    def pick_a_vendor
      if Rails.env.test?
        :mock
      else
        available_vendors.sample
      end
    end

    def available_vendors
      @_vendors ||= Figaro.env.proofing_vendors.split(/\W+/).map(&:to_sym)
    end
  end
end
