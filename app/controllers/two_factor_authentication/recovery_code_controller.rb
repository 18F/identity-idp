module TwoFactorAuthentication
  class RecoveryCodeController < ApplicationController
    before_action :confirm_two_factor_authenticated

    def show
      @code = create_new_code
    end

    def acknowledge
      redirect_to after_sign_in_path_for(current_user)
    end

    private

    def create_new_code
      generator = RecoveryCodeGenerator.new(current_user)
      code = generator.create
      if current_user.active_profile.present?
        reencrypt_pii_recovery(generator.user_access_key)
      end
      code
    end

    def reencrypt_pii_recovery(uak)
      profile = current_user.active_profile
      cacher = Pii::Cacher.new(current_user, user_session)
      pii_attributes = cacher.fetch
      profile.update!(encrypted_pii_recovery: pii_attributes.encrypted(uak))
    end
  end
end
