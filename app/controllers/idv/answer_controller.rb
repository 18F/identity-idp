class Idv::AnswerController < ApplicationController
  def create
    session[:resolution].questions[session[:question_number] ].answer =  params['answer']
    session[:question_number] += 1
    if session[:question_number] < session[:resolution].questions.count
      question = session[:resolution].questions[session[:question_number]]
      if question.choices.nil?
        render 'idv/textquestion', locals: {quest: question}
      else
        render 'idv/question', locals: {quest: question}
      end
    else
      write_success
    end
  end

  private
  def write_success
    agent = Proofer::Agent.new(vendor: :mock)
    confirmation = agent.submit_answers(session[:answers], session[:resolution].session_id)
    #TODO: actually alter the user
    cleanup_session
    if confirmation.success
      render 'idv/success'
    else
      render 'idv/fail'
    end
  end

  def cleanup_session
    session.delete(:resolution)
    session.delete(:question_number)
  end
end