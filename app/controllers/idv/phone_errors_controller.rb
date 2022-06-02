module Idv
  class PhoneErrorsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_phone_step_needed
    before_action :set_gpo_letter_available

    def warning
      @remaining_attempts = throttle.remaining_count
      track_event(type: :warning)
    end

    def timeout
      @remaining_step_attempts = throttle.remaining_count
    end

    def jobfail
      @remaining_attempts = throttle.remaining_count
      track_event(type: :jobfail)
    end

    def failure
      @expires_at = throttle.expires_at
      track_event(type: :failure)
    end

    private

    def throttle
      Throttle.new(user: idv_session.current_user, throttle_type: :proof_address)
    end

    def confirm_idv_phone_step_needed
      return unless user_fully_authenticated?
      redirect_to idv_review_url if idv_session.user_phone_confirmation == true
    end

    def track_event(type:)
      attributes = { type: type }
      if type == :failure
        attributes[:throttle_expires_at] = @expires_at
      else
        attributes[:remaining_attempts] = @remaining_attempts
      end

      analytics.idv_phone_error_visited(**attributes)
    end

    # rubocop:disable Naming/MemoizedInstanceVariableName
    def set_gpo_letter_available
      return @gpo_letter_available if defined?(@gpo_letter_available)
      @gpo_letter_available ||= FeatureManagement.enable_gpo_verification? &&
                                !Idv::GpoMail.new(current_user).mail_spammed? &&
                                !(sp_session[:ial2_strict] &&
                                  !IdentityConfig.store.gpo_allowed_for_strict_ial2)
    end
    # rubocop:enable Naming/MemoizedInstanceVariableName
  end
end
