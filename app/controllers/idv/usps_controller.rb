# :reek:TooManyMethods
module Idv
  class UspsController < ApplicationController # rubocop:disable Metrics/ClassLength
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed
    before_action :confirm_user_completed_idv_profile_step
    before_action :confirm_mail_not_spammed
    before_action :max_attempts_reached, only: [:update]

    def index
      @presenter = UspsPresenter.new(current_user)
    end

    def create
      create_user_event(:usps_mail_sent, current_user)
      idv_session.address_verification_mechanism = :usps

      if current_user.decorate.pending_profile_requires_verification?
        resend_letter
        redirect_to idv_come_back_later_url
      else
        redirect_to idv_review_url
      end
    end

    def update
      result = submit_form_and_perform_resolution
      analytics.track_event(Analytics::IDV_USPS_ADDRESS_SUBMITTED, result.to_h)
      result.success? ? resolution_success(pii) : failure
    end

    def usps_mail_service
      @_usps_mail_service ||= Idv::UspsMail.new(current_user)
    end

    private

    def submit_form_and_perform_resolution
      result = idv_form.submit(profile_params)
      result = perform_resolution(pii) if result.success?
      result
    end

    def failure
      redirect_to idv_usps_url unless performed?
    end

    def pii
      hash = {}
      update_hash_with_address(hash)
      update_hash_with_non_address_pii(hash)
      hash
    end

    def update_hash_with_address(hash)
      profile_params.each { |key, value| hash[key] = value }
    end

    def update_hash_with_non_address_pii(hash)
      pii_h = pii_to_h
      %w[first_name middle_name last_name dob phone ssn].each do |key|
        hash[key] = pii_h[key]
      end
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
      { 'vendor_phone_confirmation': false,
        'user_phone_confirmation': false,
        'resolution_successful': 'phone',
        'address_verification_mechanism': 'usps',
        'profile_confirmation': true,
        'params': hash,
        'applicant': hash,
        'uuid': current_user.uuid }
    end

    def confirm_mail_not_spammed
      redirect_to idv_review_url if idv_session.address_mechanism_chosen? &&
                                    usps_mail_service.mail_spammed?
    end

    def confirm_user_completed_idv_profile_step
      # If the user has a pending profile, they may have completed idv in a
      # different session and need a letter resent now
      return if current_user.decorate.pending_profile_requires_verification?
      return if idv_session.profile_confirmation == true

      redirect_to idv_session_url
    end

    def resend_letter
      confirmation_maker = confirmation_maker_perform
      send_reminder
      return unless FeatureManagement.reveal_usps_code?
      session[:last_usps_confirmation_code] = confirmation_maker.otp
    end

    def confirmation_maker_perform
      confirmation_maker = UspsConfirmationMaker.new(
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

    def perform_resolution(pii_from_doc)
      idv_result = Idv::Agent.new(pii_from_doc).proof(:resolution)
      success = idv_result[:success]
      throttle_failure unless success
      form_response(idv_result, success)
    end

    def form_response(result, success)
      FormResponse.new(success: success, errors: result[:errors])
    end

    def throttle_failure
      attempter.increment
      flash_error
    end

    def flash_error
      flash[:error] = error_message
      redirect_to idv_usps_url
    end

    def max_attempts_reached
      flash_error if attempter.exceeded?
    end

    def error_message
      I18n.t('idv.failure.sessions.' + (attempter.exceeded? ? 'fail' : 'heading'))
    end

    def attempter
      @attempter ||= Idv::Attempter.new(idv_session.current_user)
    end

    def send_reminder
      current_user.confirmed_email_addresses.each do |email_address|
        UserMailer.letter_reminder(email_address.email).deliver_later
      end
    end
  end
end
