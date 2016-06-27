module Idv
  class SessionsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated

    def index
    end

    def create
      resolution = setup_idv_session
      if resolution.success
        set_idv_resolution(resolution)
        set_idv_question_number(0)
        set_idv_pii(idv_applicant)
        redirect_to idv_questions_path
      else
        flash[:error] = I18n.t('idv.titles.fail')
        redirect_to idv_sessions_path
      end
    end

    private

    def setup_idv_session
      agent = Proofer::Agent.new(vendor: pick_a_vendor)
      app_vars = applicant_params.delete_if { |_key, value| value.blank? }
      applicant = Proofer::Applicant.new(app_vars)
      set_idv_applicant(applicant)
      set_idv_vendor(agent.vendor)
      agent.start(applicant)
    end

    # rubocop:disable MethodLength
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
