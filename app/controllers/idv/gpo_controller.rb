module Idv
  class GpoController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed
    before_action :confirm_user_completed_idv_profile_step
    before_action :confirm_mail_not_spammed
    before_action :confirm_gpo_allowed_if_strict_ial2
    before_action :max_attempts_reached, only: [:update]

    def index
      @presenter = GpoPresenter.new(current_user, url_options)
      current_async_state = async_state

      if current_async_state.none?
        analytics.idv_gpo_address_visited(
          letter_already_sent: @presenter.letter_already_sent?,
        )
        render :index
      elsif current_async_state.in_progress?
        render :wait
      elsif current_async_state.missing?
        analytics.proofing_address_result_missing
        render :index
      elsif current_async_state.done?
        async_state_done(current_async_state)
      end
    end

    def create
      update_tracking
      idv_session.address_verification_mechanism = :gpo

      if resend_requested? && pii_locked?
        redirect_to capture_password_url
      elsif resend_requested?
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
      @gpo_mail_service ||= Idv::GpoMail.new(current_user)
    end

    private

    def update_tracking
      analytics.idv_gpo_address_letter_requested(resend: resend_requested?)
      create_user_event(:gpo_mail_sent, current_user)

      ProofingComponent.create_or_find_by(user: current_user).update(address_check: 'gpo_letter')
    end

    def resend_requested?
      current_user.decorate.pending_profile_requires_verification?
    end

    def failure
      redirect_to idv_gpo_url unless performed?
    end

    def confirm_gpo_allowed_if_strict_ial2
      return unless sp_session[:ial2_strict]
      return if IdentityConfig.store.gpo_allowed_for_strict_ial2
      redirect_to idv_phone_url
    end

    def pii(address_pii)
      address_pii.dup.merge(non_address_pii)
    end

    def non_address_pii
      pii_to_h.
        slice('first_name', 'middle_name', 'last_name', 'dob', 'phone', 'ssn').
        merge(
          uuid: current_user.uuid,
          uuid_prefix: ServiceProvider.find_by(issuer: sp_session[:issuer])&.app_id,
        )
    end

    def pii_to_h
      JSON.parse(
        Pii::Cacher.new(current_user, user_session).fetch_string,
      )
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
      analytics.idv_gpo_address_letter_enqueued(enqueued_at: Time.zone.now, resend: true)
      confirmation_maker = confirmation_maker_perform
      send_reminder
      return unless FeatureManagement.reveal_gpo_code?
      session[:last_gpo_confirmation_code] = confirmation_maker.otp
    end

    def confirmation_maker_perform
      confirmation_maker = GpoConfirmationMaker.new(
        pii: Pii::Cacher.new(current_user, user_session).fetch,
        service_provider: current_sp,
        profile: current_user.pending_profile,
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
        throttle_type: :proof_address,
      }
    end

    def idv_attempter_increment
      Throttle.new(**idv_throttle_params).increment!
    end

    def idv_attempter_throttled?
      Throttle.new(**idv_throttle_params).throttled?
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
        analytics.throttler_rate_limit_triggered(
          throttle_type: :proof_address,
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
        UserMailer.letter_reminder(current_user, email_address.email).deliver_now_or_later
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
      )
    end

    def async_state
      dcs_uuid = idv_session.idv_gpo_document_capture_session_uuid
      dcs = DocumentCaptureSession.find_by(uuid: dcs_uuid)
      return ProofingSessionAsyncResult.none if dcs_uuid.nil?
      return missing if dcs.nil?

      proofing_job_result = dcs.load_proofing_result
      return missing if proofing_job_result.nil?

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
      analytics.idv_gpo_address_submitted(**result.to_h)
      Db::SpCost::AddSpCost.call(current_sp, 2, :lexis_nexis_resolution)
      Db::ProofingCost::AddUserProofingCost.call(current_user.id, :lexis_nexis_resolution)
    end

    def delete_async
      idv_session.idv_gpo_document_capture_session_uuid = nil
    end

    def missing
      flash[:info] = I18n.t('idv.failure.timeout')
      delete_async
      ProofingSessionAsyncResult.missing
    end

    def pii_locked?
      !Pii::Cacher.new(current_user, user_session).exists_in_session?
    end
  end
end
