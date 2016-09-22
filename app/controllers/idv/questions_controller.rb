module Idv
  class QuestionsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_vendor_session_started

    def index
      render_next_question
    end

    def create
      idv_session.answer_next_question(idv_session.question_number, params.require('answer'))
      redirect_to idv_questions_path
    end

    private

    def render_next_question
      questions = idv_session.resolution.questions
      question_number = idv_session.question_number
      if more_questions?
        @question_sequence = question_number + 1
        @question = questions[question_number]
      else
        redirect_to idv_confirmations_path
      end
    end

    def more_questions?
      questions = idv_session.questions
      question_number = idv_session.question_number
      questions && question_number < questions.count
    end
  end
end
