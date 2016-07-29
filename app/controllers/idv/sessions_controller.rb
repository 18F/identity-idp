module Idv
  class SessionsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated

    def index
    end

    def create
      resolution = start_idv_session
      if resolution.success
        init_questions_and_profile(resolution)
        redirect_to idv_questions_path
      else
        flash[:error] = I18n.t('idv.titles.fail')
        redirect_to idv_sessions_path
      end
    end

    private

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
      app_vars = applicant_params.delete_if { |_key, value| value.blank? }
      Proofer::Applicant.new(app_vars)
    end

    def init_questions_and_profile(resolution)
      self.idv_resolution = resolution
      self.idv_question_number = 0
      idv_profile_from_applicant(idv_applicant)
    end

    # rubocop:disable MethodLength
    # This method is single statement spread across many lines for readability
    def applicant_params
      params.slice(
        :first_name,
        :last_name,
        :phone,
        :email,
        :dob,
        :ssn,
        :ccn,
        :mortgage,
        :home_equity_line,
        :auto_loan,
        :bank_routing,
        :bank_acct,
        :address1,
        :address2,
        :city,
        :state,
        :zipcode
      )
    end
    # rubocop:enable MethodLength

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
