# :reek:TooManyMethods
module Idv
  class UspsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed
    before_action :confirm_user_completed_idv_profile_step
    before_action :confirm_mail_not_spammed

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
      form_result = idv_form.submit(profile_params)
      analytics.track_event(Analytics::IDV_ADDRESS_SUBMITTED, form_result.to_h)
      if form_result.success?
        result = perform_resolution(pii)
        return success(pii) if result.success?
      end
      failure
    end

    def usps_mail_service
      @_usps_mail_service ||= Idv::UspsMail.new(current_user)
    end

    private

    def failure
      redirect_to idv_usps_url
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

    def success(hash)
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
      confirmation_maker = UspsConfirmationMaker.new(
        pii: Pii::Cacher.new(current_user, user_session).fetch,
        issuer: sp_session[:issuer],
        profile: current_user.decorate.pending_profile,
      )
      confirmation_maker.perform

      return unless FeatureManagement.reveal_usps_code?
      session[:last_usps_confirmation_code] = confirmation_maker.otp
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
      FormResponse.new(success: idv_result[:success], errors: idv_result[:errors])
    end
  end
end
