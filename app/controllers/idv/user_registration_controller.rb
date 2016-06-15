class Idv::UserRegistrationController < ApplicationController
  def create
    agent = Proofer::Agent.new(vendor: :mock)
    app_vars = params.slice(:first_name, :last_name, :dob)
    applicant = Proofer::Applicant.new(app_vars)
    session[:resolution] = agent.start(applicant)
    session[:question_number] = 0
    render 'idv/question', locals: {quest: session[:resolution].questions[session[:question_number]]}
  end
end