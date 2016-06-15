class Idv::SessionsController < ApplicationController
  def index
  end

  def create
    agent = Proofer::Agent.new(vendor: :mock)
    app_vars = params.slice(:first_name, :last_name, :dob)
    applicant = Proofer::Applicant.new(app_vars)
    session[:resolution] = agent.start(applicant)
    session[:question_number] = 0
    redirect_to idv_questions_path
  end
end
