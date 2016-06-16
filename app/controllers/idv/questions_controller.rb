class Idv::QuestionsController < ApplicationController
  include IdvSession

  def index
    if proofing_session_started?
      render_next_question
    else
      redirect_to idv_sessions_path
    end
  end

  def create
    resolution.questions[question_number].answer = params.require('answer')
    session[:question_number] += 1
    redirect_to idv_questions_path
  end

  private

  def render_next_question
    if question_number < resolution.questions.count
      @question_sequence = question_number + 1 
      @question = resolution.questions[question_number]
    else
      redirect_to idv_confirmations_path
    end 
  end
end
