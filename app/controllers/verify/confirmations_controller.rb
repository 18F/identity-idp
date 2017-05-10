module Verify
  class ConfirmationsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_vendor_session_started
    before_action :confirm_profile_has_been_created

    def show
      track_final_idv_event

      finish_proofing_success
    end

    def update
      redirect_to next_step
    end

    private

    def next_step
      if session[:sp]
        return account_path if current_user.decorate.pending_profile?
        sign_up_completed_url
      else
        after_sign_in_path_for(current_user)
      end
    end

    def confirm_profile_has_been_created
      redirect_to account_path if idv_session.profile.blank?
    end

    def track_final_idv_event
      result = {
        success: true,
        new_phone_added: idv_session.params['phone_confirmed_at'].present?,
      }
      analytics.track_event(Analytics::IDV_FINAL, result)
    end

    def finish_proofing_success
      @code = personal_key
      idv_session.complete_session
      idv_session.personal_key = nil
      create_account_verified_event
      flash.now[:success] = t('idv.messages.confirm')
      flash[:allow_confirmations_continue] = true
    end

    def create_account_verified_event
      CreateVerifiedAccountEvent.new(current_user).call
    end

    def personal_key
      idv_session.personal_key || generate_personal_key
    end

    def generate_personal_key
      cacher = Pii::Cacher.new(current_user, user_session)
      idv_session.profile.encrypt_recovery_pii(cacher.fetch)
    end
  end
end
