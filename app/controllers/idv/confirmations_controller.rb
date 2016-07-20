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
        finish_proofing_success
      else
        finish_proofing_failure
      end
      clear_idv_session
    end

    def finish_proofing_failure
      # do not store PII that failed.
      idv_profile.destroy
      analytics.track_event('IdV Failed')
    end

    def finish_proofing_success
      complete_idv_profile
      flash[:success] = I18n.t('idv.titles.complete')
      analytics.track_event('IdV Successful')
      redirect_to after_sign_in_path_for(current_user)
    end
  end
end
