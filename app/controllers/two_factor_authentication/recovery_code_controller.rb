module TwoFactorAuthentication
  class RecoveryCodeController < ApplicationController
    before_action :confirm_two_factor_authenticated

    def show
      @code = create_new_code
      analytics.track_event(Analytics::USER_REGISTRATION_RECOVERY_CODE_VISIT)
    end

    def acknowledge
      redirect_to after_sign_in_path_for(current_user)
    end

    private

    def create_new_code
      if current_user.active_profile.present?
        reencrypt_pii_recovery
      else
        generator = RecoveryCodeGenerator.new(current_user)
        generator.create
      end
    end

    def reencrypt_pii_recovery
      profile = current_user.active_profile
      cacher = Pii::Cacher.new(current_user, user_session)
      pii_attributes = cacher.fetch
      profile.encrypt_recovery_pii(pii_attributes)
      profile.save!
      profile.recovery_code
    end
  end
end
