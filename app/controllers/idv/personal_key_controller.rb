module Idv
  class PersonalKeyController < ApplicationController
    include IdvSession
    include StepIndicatorConcern
    include SecureHeadersConcern

    before_action :apply_secure_headers_override
    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_vendor_session_started
    before_action :confirm_profile_has_been_created

    def show
      analytics.idv_personal_key_visited(proofing_method: "#{proofing_method} verification")
      add_proofing_component

      finish_idv_session
    end

    def update
      user_session[:need_personal_key_confirmation] = false

      analytics.idv_personal_key_submitted(proofing_method: "#{proofing_method} verification")
      redirect_to next_step
    end

    private

    def proofing_method
      user_session['idv']['address_verification_mechanism']
    end

    def next_step
      if pending_profile? && idv_session.address_verification_mechanism == 'gpo'
        idv_come_back_later_url
      elsif in_person_enrollment?
        idv_in_person_ready_to_verify_url
      elsif blocked_by_device_profiling?
        idv_setup_errors_url
      elsif session[:sp] && !pending_profile?
        sign_up_completed_url
      else
        after_sign_in_path_for(current_user)
      end
    end

    def confirm_profile_has_been_created
      redirect_to account_url if idv_session.profile.blank?
    end

    def add_proofing_component
      ProofingComponent.find_or_create_by(user: current_user).update(verified_at: Time.zone.now)
    end

    def finish_idv_session
      @code = personal_key
      user_session[:personal_key] = @code
      idv_session.personal_key = nil

      irs_attempts_api_tracker.idv_personal_key_generated

      if idv_session.address_verification_mechanism == 'gpo'
        flash.now[:success] = t('idv.messages.mail_sent')
      else
        flash.now[:success] = t('idv.messages.confirm')
      end
      flash[:allow_confirmations_continue] = true
    end

    def personal_key
      idv_session.personal_key || generate_personal_key
    end

    def generate_personal_key
      cacher = Pii::Cacher.new(current_user, user_session)
      idv_session.profile.encrypt_recovery_pii(cacher.fetch)
    end

    def in_person_enrollment?
      return false unless IdentityConfig.store.in_person_proofing_enabled
      current_user.pending_in_person_enrollment.present?
    end

    def pending_profile?
      current_user.pending_profile?
    end

    def blocked_by_device_profiling?
      return false unless IdentityConfig.store.proofing_device_profiling_decisioning_enabled
      proofing_component = ProofingComponent.find_by(user: current_user)
      # pass users who are inbetween feature flag being enabled and have not had a check run.
      return false if proofing_component.threatmetrix_review_status.nil?
      proofing_component.threatmetrix_review_status != 'pass'
    end
  end
end
