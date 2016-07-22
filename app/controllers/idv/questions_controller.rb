module Idv
  class QuestionsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated

    def index
      if proofing_session_started?
        render_next_question
      else
        redirect_to idv_sessions_path
      end
    end

    def create
      idv_resolution.questions[idv_question_number].answer = params.require('answer')
      self.idv_question_number += 1
      redirect_to idv_questions_path
    end

    private

    def render_next_question
      questions = idv_resolution.questions
      if questions && idv_question_number < questions.count
        @question_sequence = idv_question_number + 1
        @question = questions[idv_question_number]
      else
        redirect_to idv_confirmations_path
      end
    end
  end
end
