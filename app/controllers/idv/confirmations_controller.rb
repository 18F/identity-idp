module Idv
  class ConfirmationsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated

    def index
      if proofing_session_started?
        if idv_question_number >= idv_resolution.questions.count
          submit_answers
        else
          redirect_to idv_questions_path
        end
      else
        redirect_to idv_sessions_path
      end
    end

    private

    def submit_answers
      agent = Proofer::Agent.new(vendor: idv_vendor, applicant: idv_applicant)
      @idv_vendor = idv_vendor
      @confirmation = agent.submit_answers(idv_resolution.questions, idv_resolution.session_id)
      if @confirmation.success?
        pii = PII.find(pii_id)
        pii.verified = true
        pii.activate!
      end
      clear_idv_session
    end
  end
end
