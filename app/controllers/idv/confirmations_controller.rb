module Idv
  class ConfirmationsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_vendor_session_started

    def index
      if idv_questions && idv_questions.any?
        handle_kbv
      else
        handle_without_kbv
      end
    end

    private

    def idv_questions
      idv_session.questions
    end

    def handle_kbv
      if idv_session.question_number >= idv_questions.count
        submit_answers
      else
        redirect_to idv_questions_path
      end
    end

    def handle_without_kbv
      # should we do further interrogate idv_resolution?
      # see https://github.com/18F/identity-private/issues/485
      finish_proofing_success
    end

    def submit_answers
      @idv_vendor = idv_session.vendor
      resolution = idv_session.resolution
      @confirmation = idv_agent.submit_answers(resolution.questions, resolution.session_id)
      if @confirmation.success?
        finish_proofing_success
      else
        finish_proofing_failure
      end
    end

    def finish_proofing_failure
      # do not store PII that failed.
      idv_session.profile.destroy
      idv_session.clear
      analytics.track_event('IdV Failed')
      if idv_attempter.exceeded?
        redirect_to idv_fail_url
      else
        redirect_to idv_retry_url
      end
    end

    def finish_proofing_success
      idv_attempter.reset
      idv_session.complete_profile
      idv_session.clear
      flash[:success] = I18n.t('idv.titles.complete')
      analytics.track_event('IdV Successful')
      redirect_to after_sign_in_path_for(current_user)
    end
  end
end
