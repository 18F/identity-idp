module Idv
  class GpoController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed
    before_action :confirm_user_completed_idv_profile_step
    before_action :confirm_mail_not_spammed
    before_action :max_attempts_reached, only: [:update]

    def index
      @presenter = GpoPresenter.new(current_user, url_options)
      current_async_state = async_state

      if current_async_state.none?
        analytics.track_event(Analytics::IDV_GPO_ADDRESS_VISITED)
        render :index
      elsif current_async_state.in_progress?
        render :wait
      elsif current_async_state.timed_out?
        analytics.track_event(Analytics::PROOFING_ADDRESS_TIMEOUT)
        render :index
      elsif current_async_state.done?
        async_state_done(current_async_state)
      end
    end

    def create
      update_tracking
      idv_session.address_verification_mechanism = :gpo

      if current_user.decorate.pending_profile_requires_verification?
        resend_letter
        redirect_to idv_come_back_later_url
      else
        redirect_to idv_review_url
      end
    end

    def update
      result = idv_form.submit(profile_params)
      enqueue_job if result.success?
      redirect_to idv_gpo_path
    end

    def gpo_mail_service
      @_gpo_mail_service ||= Idv::GpoMail.new(current_user)
    end

    private

    def update_tracking
      analytics.track_event(Analytics::IDV_GPO_ADDRESS_LETTER_REQUESTED)
      create_user_event(:gpo_mail_sent, current_user)
      Db::ProofingComponent::Add.call(current_user.id, :address_check, 'gpo_letter')
    end

    def failure
      redirect_to idv_gpo_url unless performed?
    end

    def pii(address_pii)
      address_pii.dup.merge(non_address_pii)
    end

    def non_address_pii
      pii_to_h.
        slice('first_name', 'middle_name', 'last_name', 'dob', 'phone', 'ssn').
        merge(uuid_prefix: ServiceProvider.find_by(issuer: sp_session[:issuer])&.app_id)
    end

    def pii_to_h
      JSON.parse(user_session[:decrypted_pii])
    end

    def resolution_success(hash)
      idv_session_settings(hash).each { |key, value| user_session['idv'][key] = value }
      resend_letter
      redirect_to idv_review_url
    end

    def idv_session_settings(hash)
      { vendor_phone_confirmation: false,
        user_phone_confirmation: false,
        resolution_successful: 'phone',
        address_verification_mechanism: 'gpo',
        profile_confirmation: true,
        params: hash,
        applicant: hash,
        uuid: current_user.uuid }
    end

    def confirm_mail_not_spammed
      redirect_to idv_review_url if idv_session.address_mechanism_chosen? &&
                                    gpo_mail_service.mail_spammed?
    end

    def confirm_user_completed_idv_profile_step
      # If the user has a pending profile, they may have completed idv in a
      # different session and need a letter resent now
      return if current_user.decorate.pending_profile_requires_verification?
      return if idv_session.profile_confirmation == true

      redirect_to idv_doc_auth_url
    end

    def resend_letter
      confirmation_maker = confirmation_maker_perform
      send_reminder
      return unless FeatureManagement.reveal_gpo_code?
      session[:last_gpo_confirmation_code] = confirmation_maker.otp
    end

    def confirmation_maker_perform
      confirmation_maker = GpoConfirmationMaker.new(
        pii: Pii::Cacher.new(current_user, user_session).fetch,
        issuer: sp_session[:issuer],
        profile: current_user.decorate.pending_profile,
      )
      confirmation_maker.perform
      confirmation_maker
    end

    def idv_form
      Idv::AddressForm.new(
        user: current_user,
        previous_params: idv_session.previous_profile_step_params,
      )
    end

    def profile_params
      params.require(:idv_form).permit(Idv::AddressForm::ATTRIBUTES)
    end

    def form_response(result, success)
      FormResponse.new(
        success: success,
        errors: result[:errors],
        extra: {
          pii_like_keypaths: [[:errors, :zipcode]],
        },
      )
    end

    def idv_throttle_params
      {
        user: idv_session.current_user,
        throttle_type: :idv_resolution,
      }
    end

    def idv_attempter_increment
      Throttle.for(**idv_throttle_params).increment
    end

    def idv_attempter_throttled?
      Throttle.for(**idv_throttle_params).throttled?
    end

    def throttle_failure
      idv_attempter_increment
      flash_error
    end

    def flash_error
      flash[:error] = error_message
      redirect_to idv_gpo_url
    end

    def max_attempts_reached
      if idv_attempter_throttled?
        analytics.track_event(
          Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
          throttle_type: :idv_resolution,
          step_name: :gpo,
        )
        flash_error
      end
    end

    def error_message
      I18n.t('idv.failure.sessions.' + (idv_attempter_throttled? ? 'fail' : 'heading'))
    end

    def send_reminder
      current_user.confirmed_email_addresses.each do |email_address|
        UserMailer.letter_reminder(current_user, email_address.email).deliver_now
      end
    end

    def enqueue_job
      return if idv_session.idv_gpo_document_capture_session_uuid
      idv_session.previous_gpo_step_params = profile_params.to_h

      document_capture_session = DocumentCaptureSession.create(
        user_id: current_user.id,
        issuer: sp_session[:issuer],
        ial2_strict: sp_session[:ial2_strict],
        requested_at: Time.zone.now,
      )

      document_capture_session.create_proofing_session
      idv_session.idv_gpo_document_capture_session_uuid = document_capture_session.uuid
      applicant = pii(profile_params.to_h)
      Idv::Agent.new(applicant).proof_resolution(
        document_capture_session,
        should_proof_state_id: false,
        trace_id: amzn_trace_id,
        document_expired: idv_session.document_expired,
      )
    end

    def async_state
      dcs_uuid = idv_session.idv_gpo_document_capture_session_uuid
      dcs = DocumentCaptureSession.find_by(uuid: dcs_uuid)
      return ProofingSessionAsyncResult.none if dcs_uuid.nil?
      return timed_out if dcs.nil?

      proofing_job_result = dcs.load_proofing_result
      return timed_out if proofing_job_result.nil?

      proofing_job_result
    end

    def async_state_done(async_state)
      idv_result = async_state.result
      success = idv_result[:success]

      throttle_failure unless success
      result = form_response(idv_result, success)

      delete_async

      async_state_done_analytics(result)
      applicant = pii(idv_session.previous_gpo_step_params)
      result.success? ? resolution_success(applicant) : failure
    end

    def async_state_done_analytics(result)
      analytics.track_event(Analytics::IDV_GPO_ADDRESS_SUBMITTED, result.to_h)
      Db::SpCost::AddSpCost.call(sp_session[:issuer].to_s, 2, :lexis_nexis_resolution)
      Db::ProofingCost::AddUserProofingCost.call(current_user.id, :lexis_nexis_resolution)
    end

    def delete_async
      idv_session.idv_gpo_document_capture_session_uuid = nil
    end

    def timed_out
      flash[:info] = I18n.t('idv.failure.timeout')
      delete_async
      ProofingSessionAsyncResult.timed_out
    end
  end
end
