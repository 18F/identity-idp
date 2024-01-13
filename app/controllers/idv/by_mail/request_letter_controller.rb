module Idv
  module ByMail
    class RequestLetterController < ApplicationController
      include Idv::PluginAware
      require_plugin :verify_by_mail

      include Idv::AvailabilityConcern
      include IdvStepConcern
      skip_before_action :confirm_no_pending_gpo_profile
      include Idv::StepIndicatorConcern

      before_action :confirm_mail_not_rate_limited
      before_action :confirm_step_allowed
      before_action :confirm_profile_not_too_old

      def index
        trigger_plugin_hook :step_started, step: :request_letter,
                                           resend_requested: resend_requested?

        @applicant = idv_session.applicant
        @presenter = RequestLetterPresenter.new(current_user, url_options)
        @step_indicator_current_step = step_indicator_current_step
      end

      def create
        clear_future_steps!

        if resend_requested? && pii_locked?
          redirect_to capture_password_url
          return
        end

        idv_session.address_verification_mechanism = :gpo

        if resend_requested?
          # Resends are processed _right away_, whereas the initial send is
          # delayed until the profile is minted.
          resend_letter
          flash[:success] = t('idv.messages.gpo.another_letter_on_the_way')
        end

        trigger_plugin_hook(
          :step_completed,
          step: :request_letter,
          # Note that "did we enqueue a letter already?" and "was the user requesting a resend?"
          # are different questions that _happen_ to have the same answer here.
          letter_enqueued: resend_requested?,
          resend_requested: resend_requested?,
        )
      end

      def gpo_mail_service
        @gpo_mail_service ||= Idv::GpoMail.new(current_user)
      end

      def self.step_info
        Idv::StepInfo.new(
          key: :request_letter,
          controller: self,
          action: :index,
          next_steps: [:enter_password],
          preconditions: ->(idv_session:, user:) do
            idv_session.verify_info_step_complete? || user.gpo_verification_pending_profile?
          end,
          undo_step: ->(idv_session:, user:) { idv_session.address_verification_mechanism = nil },
        )
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

      def resend_requested?
        current_user.gpo_verification_pending_profile?
      end

      def confirm_mail_not_rate_limited
        redirect_to idv_enter_password_url if gpo_mail_service.rate_limited?
      end

      def resend_letter
        confirmation_maker = confirmation_maker_perform
        send_reminder
        return unless FeatureManagement.reveal_gpo_code?
        session[:last_gpo_confirmation_code] = confirmation_maker.otp
      end

      def confirmation_maker_perform
        confirmation_maker = GpoConfirmationMaker.new(
          pii: pii,
          service_provider: current_sp,
          profile: current_user.pending_profile,
        )
        confirmation_maker.perform
        confirmation_maker
      end

      def pii
        Pii::Cacher.new(current_user, user_session).
          fetch(current_user.gpo_verification_pending_profile.id)
      end

      def send_reminder
        current_user.send_email_to_all_addresses(:letter_reminder)
      end

      def pii_locked?
        !Pii::Cacher.new(current_user, user_session).exists_in_session?
      end
    end
  end
end
