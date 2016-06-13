class IdvController < ApplicationController
  def register_user(args = nil)
    agent = Proofer::Agent.new(vendor: :mock)
    app_vars = params.slice(:first_name, :last_name, :dob)
    applicant = Proofer::Applicant.new(app_vars)
    session[:resolution] = agent.start(applicant)
    session[:question_number] = 0
    render 'question', locals: {quest: session[:resolution].questions[session[:question_number]]}
  end

  def answer
    #TODO: do some stuff with the actual question
    session[:question_number] += 1
    if session[:question_number] < session[:resolution].questions.count
      question = session[:resolution].questions[session[:question_number]]
      if question.choices.nil?
        render 'textquestion', locals: {quest: question}
      else
        render 'question', locals: {quest: question}
      end
    else
      success
    end
  end

  def success
    #write resolution to database
    session.delete(:resolution)
  end
end
