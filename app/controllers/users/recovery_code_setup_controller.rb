module Users
  class RecoveryCodeSetupController < ApplicationController
    before_action :authenticate_user!
    before_action :confirm_two_factor_authenticated, if: :two_factor_enabled?

    def new
      @presenter = TwoFactorAuthCode::RecoveryCodePresenter.new(data: {:current_user => current_user}, view: self.view_context)
      result = RecoveryCodeVisitForm.new.submit(params)
      analytics.track_event(Analytics::RECOVERY_CODE_SETUP_VISIT, result.to_h)
      mark_user_as_fully_authenticated
    end

    def index
      new
    end

    def create
      # binding.pry
      analytics.track_event(Analytics::RECOVERY_CODE_CREATED)
      Event.create(user_id: current_user.id, event_type: :new_personal_key)
      puts "############### In CREATE RECOVERY_CODE"
      redirect_to sign_up_personal_key_url
    end

    def mark_user_as_fully_authenticated
      user_session[TwoFactorAuthentication::NEED_AUTHENTICATION] = false
      user_session[:authn_at] = Time.zone.now
    end

    def two_factor_enabled?
      MfaPolicy.new(current_user).two_factor_enabled?
    end
  end
end
