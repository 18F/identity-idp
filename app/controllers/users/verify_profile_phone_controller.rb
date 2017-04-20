module Users
  class VerifyProfilePhoneController < ApplicationController
    include PhoneConfirmation

    before_action :confirm_two_factor_authenticated
    before_action :confirm_phone_verification_needed

    def index
      prompt_to_confirm_phone(phone: profile_phone, context: 'profile')
    end

    private

    def confirm_phone_verification_needed
      return if unverified_phone?
      redirect_to account_url
    end

    def pending_profile_requires_verification?
      current_user.decorate.pending_profile_requires_verification?
    end

    def unverified_phone?
      pending_profile_requires_verification? &&
        pending_profile.phone_confirmed? &&
        current_user.phone != profile_phone
    end

    def profile_phone
      @_profile_phone ||= decrypted_pii.phone.to_s
    end

    def pending_profile
      @_pending_profile ||= current_user.decorate.pending_profile
    end

    def decrypted_pii
      @_decrypted_pii ||= begin
        cacher = Pii::Cacher.new(current_user, user_session)
        cacher.fetch
      end
    end
  end
end
