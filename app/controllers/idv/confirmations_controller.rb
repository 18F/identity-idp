class Idv::ConfirmationsController < ApplicationController
  include IdvSession

  def index
    if question_number >= resolution.questions.count
      submit_answers
    else
      redirect_to idv_questions_path
    end
  end

  private

  def submit_answers
    agent = Proofer::Agent.new(vendor: idv_vendor)
    @confirmation = agent.submit_answers(resolution.questions, resolution.session_id)
    #TODO: actually alter the user
    clear_idv_session
  end
end
