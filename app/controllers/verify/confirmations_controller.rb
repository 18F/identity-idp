module Verify
  class ConfirmationsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_vendor_session_started
    before_action :confirm_profile_has_been_created

    def index
      track_final_idv_event

      finish_proofing_success
    end

    private

    def confirm_profile_has_been_created
      redirect_to profile_path unless idv_session.profile.present?
    end

    def track_final_idv_event
      result = {
        success: true,
        new_phone_added: idv_session.params['phone_confirmed_at'].present?,
      }
      analytics.track_event(Analytics::IDV_FINAL, result)
    end

    def finish_proofing_success
      @recovery_code = recovery_code
      idv_session.complete_profile
      idv_session.recovery_code = nil
      flash[:allow_confirmations_continue] = true
    end

    def recovery_code
      idv_session.recovery_code || generate_recovery_code
    end

    def generate_recovery_code
      cacher = Pii::Cacher.new(current_user, user_session)
      idv_session.profile.encrypt_recovery_pii(cacher.fetch)
    end
  end
end
