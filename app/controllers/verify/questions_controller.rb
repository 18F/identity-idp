module Verify
  class QuestionsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_vendor_session_started

    def index
      if FeatureManagement.proofing_requires_kbv?
        render_next_question
      else
        redirect_to verify_confirmations_path
      end
    end

    def create
      idv_session.answer_next_question(idv_session.question_number, params.require('answer'))
      redirect_to verify_questions_path
    end

    private

    def render_next_question
      if more_questions?
        @question_sequence = question_number + 1
        @question = questions[question_number]
      else
        submit_answers
        track_kbv_event
        process_submission
      end
    end

    def more_questions?
      questions && question_number < questions.count
    end

    def questions
      idv_session.questions
    end

    def question_number
      idv_session.question_number
    end

    def submit_answers
      @_submission ||= begin
        resolution = idv_session.resolution
        idv_agent.submit_answers(resolution.questions, resolution.session_id)
      end
    end

    def track_kbv_event
      result = {
        kbv_passed: correct_answers?,
        idv_attempts_exceeded: idv_attempter.exceeded?,
        new_phone_added: idv_session.params['phone_confirmed_at'].present?
      }
      analytics.track_event(Analytics::IDV_FINAL, result)
    end

    def correct_answers?
      submit_answers.success?
    end

    def process_submission
      if correct_answers?
        redirect_to verify_confirmations_path
      else
        finish_proofing_failure
      end
    end

    def finish_proofing_failure
      # do not store PII that failed.
      idv_session.profile.destroy
      idv_session.clear
      if idv_attempter.exceeded?
        redirect_to verify_fail_path
      else
        redirect_to verify_retry_path
      end
    end
  end
end
