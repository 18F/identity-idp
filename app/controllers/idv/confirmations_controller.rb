module Idv
  class ConfirmationsController < ApplicationController
    include IdvSession
    include SecureHeadersConcern

    before_action :apply_secure_headers_override
    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_vendor_session_started
    before_action :confirm_profile_has_been_created

    def show
      @step_indicator_steps = step_indicator_steps
      track_final_idv_event

      finish_idv_session
    end

    def update
      user_session[:need_personal_key_confirmation] = false
      redirect_to next_step
    end

    def download
      personal_key = user_session[:personal_key]

      analytics.track_event(Analytics::IDV_DOWNLOAD_PERSONAL_KEY, success: personal_key.present?)

      if personal_key.present?
        data = personal_key + "\r\n"
        send_data data, filename: 'personal_key.txt'
      else
        head :bad_request
      end
    end

    private

    def step_indicator_steps
      steps = Idv::Flows::DocAuthFlow::STEP_INDICATOR_STEPS
      return steps if idv_session.address_verification_mechanism != 'gpo'
      steps.map do |step|
        step[:name] == :verify_phone_or_address ? step.merge(status: :pending) : step
      end
    end

    def next_step
      if session[:sp] && !pending_profile?
        sign_up_completed_url
      elsif pending_profile? && idv_session.address_verification_mechanism == 'gpo'
        idv_come_back_later_url
      else
        after_sign_in_path_for(current_user)
      end
    end

    def confirm_profile_has_been_created
      redirect_to account_url if idv_session.profile.blank?
    end

    def track_final_idv_event
      configured_phones = MfaContext.new(current_user).phone_configurations.map(&:phone)
      result = {
        success: true,
        new_phone_added: !configured_phones.include?(idv_session.applicant['phone']),
      }
      analytics.track_event(Analytics::IDV_FINAL, result)
      add_proofing_component
    end

    def add_proofing_component
      Db::ProofingComponent::Add.call(current_user.id, :verified_at, Time.zone.now)
    end

    def finish_idv_session
      @code = personal_key
      user_session[:personal_key] = @code
      idv_session.personal_key = nil

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

    def pending_profile?
      current_user.pending_profile?
    end
  end
end
