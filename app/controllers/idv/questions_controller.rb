class Idv::QuestionsController < ApplicationController
  def index
    redirect_to new_idv_session_path unless proofing_session_started?

    if question_number < resolution.questions.count
      @question_sequence = question_number + 1
      @question = resolution.questions[question_number]
    else
      redirect_to idv_confirmation_path
    end
  end

  def create
    session[:resolution].questions[session[:question_number]].answer = params.require('answer')
    session[:question_number] += 1
    redirect_to idv_questions_path
  end

  private

  def question_number
    session[:question_number]
  end

  def resolution
    session[:resolution]
  end

  def proofing_session_started?
    session.key?(:resolution) && session[:resolution].present?
  end
end
