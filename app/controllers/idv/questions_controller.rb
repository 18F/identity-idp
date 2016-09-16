module Idv
  class QuestionsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated

    def index
      if idv_session.proofing_started?
        render_next_question
      else
        redirect_to idv_session_path
      end
    end

    def create
      idv_session.answer_next_question(idv_session.question_number, params.require('answer'))
      redirect_to idv_questions_path
    end

    private

    def render_next_question
      questions = idv_session.resolution.questions
      question_number = idv_session.question_number
      if questions && question_number < questions.count
        @question_sequence = question_number + 1
        @question = questions[question_number]
      else
        redirect_to idv_confirmations_path
      end
    end
  end
end
