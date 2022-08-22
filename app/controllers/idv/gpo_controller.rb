module Idv
  class GpoController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed
    before_action :confirm_user_completed_idv_profile_step
    before_action :confirm_mail_not_spammed
    before_action :confirm_gpo_allowed_if_strict_ial2

    def index
      @presenter = GpoPresenter.new(current_user, url_options)
      analytics.idv_gpo_address_visited(
        letter_already_sent: @presenter.letter_already_sent?,
      )
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

    def confirm_gpo_allowed_if_strict_ial2
      return unless sp_session[:ial2_strict]
      return if IdentityConfig.store.gpo_allowed_for_strict_ial2
      redirect_to idv_phone_url
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

    def send_reminder
      current_user.confirmed_email_addresses.each do |email_address|
        UserMailer.letter_reminder(current_user, email_address.email).deliver_now_or_later
      end
    end

    def pii_locked?
      !Pii::Cacher.new(current_user, user_session).exists_in_session?
    end
  end
end
