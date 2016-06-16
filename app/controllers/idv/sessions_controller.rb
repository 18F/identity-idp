class Idv::SessionsController < ApplicationController
  def index
  end

  def create
    agent = Proofer::Agent.new(vendor: pick_a_vendor)
    app_vars = params.slice(:first_name, :last_name, :dob)
    applicant = Proofer::Applicant.new(app_vars)
    session[:idv_vendor] = agent.vendor
    session[:resolution] = agent.start(applicant)
    session[:question_number] = 0
    redirect_to idv_questions_path
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
