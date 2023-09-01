module Idv::ByMail
  class RequestLetterController < ApplicationController
    include IdvSession
    include Idv::StepIndicatorConcern
    include Idv::AbTestAnalyticsConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed
    before_action :confirm_user_completed_idv_profile_step
    before_action :confirm_mail_not_spammed
    before_action :confirm_profile_not_too_old

    def index
      @presenter = Idv::GpoPresenter.new(current_user, url_options)
      @step_indicator_current_step = step_indicator_current_step
      Funnel::DocAuth::RegisterStep.new(current_user.id, current_sp&.issuer).
        call(:usps_address, :view, true)
      analytics.idv_gpo_address_visited(
        letter_already_sent: @presenter.resend_requested?,
      )
    end

    def create
      update_tracking
      idv_session.address_verification_mechanism = :gpo

      if resend_requested? && pii_locked?
        redirect_to capture_password_url
      elsif resend_requested?
        resend_letter
        flash[:success] = t('idv.messages.gpo.another_letter_on_the_way')
        redirect_to idv_come_back_later_url
      else
        redirect_to idv_review_url
      end
    end

    def gpo_mail_service
      @gpo_mail_service ||= Idv::GpoMail.new(current_user)
    end

    private

    def confirm_profile_not_too_old
      redirect_to idv_path if gpo_mail_service.profile_too_old?
    end

    def step_indicator_current_step
      if resend_requested?
        :get_a_letter
      else
        :verify_phone_or_address
      end
    end

    def update_tracking
      Funnel::DocAuth::RegisterStep.new(current_user.id, current_sp&.issuer).
        call(:usps_letter_sent, :update, true)

      analytics.idv_gpo_address_letter_requested(
        resend: resend_requested?,
        first_letter_requested_at: first_letter_requested_at,
        hours_since_first_letter:
          gpo_mail_service.hours_since_first_letter(first_letter_requested_at),
        phone_step_attempts: gpo_mail_service.phone_step_attempts,
        **ab_test_analytics_buckets,
      )
      irs_attempts_api_tracker.idv_gpo_letter_requested(resend: resend_requested?)
      create_user_event(:gpo_mail_sent, current_user)

      ProofingComponent.find_or_create_by(user: current_user).update(address_check: 'gpo_letter')
    end

    def resend_requested?
      current_user.gpo_verification_pending_profile?
    end

    def first_letter_requested_at
      current_user.gpo_verification_pending_profile&.gpo_verification_pending_at
    end

    def confirm_mail_not_spammed
      redirect_to idv_review_url if idv_session.address_mechanism_chosen? &&
                                    gpo_mail_service.mail_spammed?
    end

    def confirm_user_completed_idv_profile_step
      # If the user has a pending profile, they may have completed idv in a
      # different session and need a letter resent now
      return if current_user.gpo_verification_pending_profile?
      return if idv_session.verify_info_step_complete?

      redirect_to idv_verify_info_url
    end

    def resend_letter
      analytics.idv_gpo_address_letter_enqueued(
        enqueued_at: Time.zone.now,
        resend: true,
        first_letter_requested_at: first_letter_requested_at,
        hours_since_first_letter:
          gpo_mail_service.hours_since_first_letter(first_letter_requested_at),
        phone_step_attempts: gpo_mail_service.phone_step_attempts,
        **ab_test_analytics_buckets,
      )
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

    def send_reminder
      current_user.send_email_to_all_addresses(:letter_reminder)
    end

    def pii_locked?
      !Pii::Cacher.new(current_user, user_session).exists_in_session?
    end
  end
end
