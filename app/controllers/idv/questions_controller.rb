class Idv::QuestionsController < ApplicationController
  def index
    redirect_to idv_new_session_path unless proofing_session_started?

    if session[:question_number] < session[:resolution].questions.count
      question = session[:resolution].questions[session[:question_number]]
      if question.choices.nil?
        render 'idv/textquestion', locals: {quest: question}
      else
        render 'idv/question', locals: {quest: question}
      end 
    else
      redirect_to idv_confirmation_path
    end
  end

  def update
    session[:resolution].questions[session[:question_number]].answer = params.require('answer')
    session[:question_number] += 1
    redirect_to idv_question_path
  end

  private

  def proofing_session_started?
    session[:resolution]
  end
end
