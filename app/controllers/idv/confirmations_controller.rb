class Idv::ConfirmationController < ApplicationController
  def index
    if session[:question_number] => session[:resolution].questions.count
      submit_answers
    else
      redirect_to idv_question_path
    end
  end

  private

  def submit_answers
    agent = Proofer::Agent.new(vendor: :mock)
    @confirmation = agent.submit_answers(session[:answers], session[:resolution].session_id)
    #TODO: actually alter the user
    cleanup_session
  end

  def cleanup_session
    session.delete(:resolution)
    session.delete(:question_number)
  end
end
