class Idv::SessionsController < ApplicationController
  include IdvSession

  before_action :confirm_two_factor_authenticated

  def index
  end

  def create
    agent = Proofer::Agent.new(vendor: pick_a_vendor)
    app_vars = params.slice(:first_name, :last_name, :dob, :ssn,
                            :ccn, :mortgage, :home_equity_line, :auto_loan, :bank_routing, :bank_acct,
                            :address1, :address2, :city, :state, :zipcode)
                 .delete_if { |key, value| value.blank? }
    applicant = Proofer::Applicant.new(app_vars)
    set_idv_applicant(applicant)
    set_idv_vendor(agent.vendor)
    resolution = agent.start(applicant)
    if resolution.success
      set_idv_resolution(resolution)
      set_idv_question_number(0)
      redirect_to idv_questions_path
    else
      flash[:error] = I18n.t('idv.titles.fail')
      redirect_to idv_sessions_path
    end
  end

  private

  def pick_a_vendor
    if Rails.env.test?
      :mock
    else
      available_vendors.sample
    end
  end

  def available_vendors
    @_vendors ||= ENV.fetch('PROOFING_VENDORS', '').split(/\W+/).map { |vendor| vendor.to_sym }
  end
end
