module Idv
  module ByMail
    class EnterCodeController < ApplicationController
      include IdvSession
      include Idv::StepIndicatorConcern
      include FraudReviewConcern

      prepend_before_action :note_if_user_did_not_receive_letter
      before_action :confirm_two_factor_authenticated
      before_action :confirm_verification_needed

      def index
        # GPO reminder emails include an "I did not receive my letter!" link that results in
        # slightly different copy on this screen.
        @user_did_not_receive_letter = !!params[:did_not_receive_letter]

        analytics.idv_verify_by_mail_enter_code_visited(
          source: if @user_did_not_receive_letter then 'gpo_reminder_email' end,
        )

        if rate_limiter.limited?
          redirect_to idv_enter_code_rate_limited_url
          return
        end

        @last_date_letter_was_sent = last_date_letter_was_sent
        @gpo_verify_form = GpoVerifyForm.new(user: current_user, pii: pii)
        @code = session[:last_gpo_confirmation_code] if FeatureManagement.reveal_gpo_code?

        gpo_mail = Idv::GpoMail.new(current_user)
        @can_request_another_letter =
          FeatureManagement.gpo_verification_enabled? &&
          !gpo_mail.rate_limited? &&
          !gpo_mail.profile_too_old?

        if pii_locked?
          redirect_to capture_password_url
        else
          render :index
        end
      end

      def pii
        Pii::Cacher.new(current_user, user_session).
          fetch(current_user.gpo_verification_pending_profile&.id)
      end

      def create
        if rate_limiter.limited?
          redirect_to idv_enter_code_rate_limited_url
          return
        end

        rate_limiter.increment!

        @gpo_verify_form = build_gpo_verify_form

        result = @gpo_verify_form.submit
        analytics.idv_verify_by_mail_enter_code_submitted(**result.to_h)
        irs_attempts_api_tracker.idv_gpo_verification_submitted(
          success: result.success?,
        )

        if !result.success?
          if rate_limiter.limited?
            redirect_to idv_enter_code_rate_limited_url
          else
            flash[:error] = @gpo_verify_form.errors.first.message if !rate_limiter.limited?
            redirect_to idv_verify_by_mail_enter_code_url
          end
          return
        end

        prepare_for_personal_key

        redirect_to idv_personal_key_url
      end

      private

      def pending_in_person_enrollment?
        return false unless IdentityConfig.store.in_person_proofing_enabled
        current_user.pending_in_person_enrollment.present?
      end

      def account_not_ready_to_be_activated?
        fraud_check_failed? || pending_in_person_enrollment?
      end

      def note_if_user_did_not_receive_letter
        if !current_user && params[:did_not_receive_letter]
          # Stash that the user didn't receive their letter.
          # Once the authentication process completes, they'll be redirected to complete their
          # GPO verification...
          session[:gpo_user_did_not_receive_letter] = true
        end

        if current_user && session.delete(:gpo_user_did_not_receive_letter)
          # ...and we can pick things up here.
          redirect_to idv_verify_by_mail_enter_code_path(did_not_receive_letter: 1)
        end
      end

      def prepare_for_personal_key
        unless account_not_ready_to_be_activated?
          event, _disavowal_token = create_user_event(:account_verified)

          UserAlerts::AlertUserAboutAccountVerified.call(
            user: current_user,
            date_time: event.created_at,
            sp_name: decorated_sp_session.sp_name,
          )
          flash[:success] = t('account.index.verification.success')
      end

        idv_session.address_verification_mechanism = 'gpo'
        idv_session.address_confirmed!
      end

      def rate_limiter
        @rate_limiter ||= RateLimiter.new(
          user: current_user,
          rate_limit_type: :verify_gpo_key,
        )
      end

      def build_gpo_verify_form
        GpoVerifyForm.new(
          user: current_user,
          pii: pii,
          otp: params_otp,
        )
      end

      def params_otp
        params.require(:gpo_verify_form).permit(:otp)[:otp]
      end

      def confirm_verification_needed
        return if current_user.gpo_verification_pending_profile?
        redirect_to account_url
      end

      def threatmetrix_enabled?
        FeatureManagement.proofing_device_profiling_decisioning_enabled?
      end

      def pii_locked?
        !Pii::Cacher.new(current_user, user_session).exists_in_session?
      end

      def last_date_letter_was_sent
        current_user.gpo_verification_pending_profile&.gpo_confirmation_codes&.
          pluck(:updated_at)&.max
      end
    end
  end
end
