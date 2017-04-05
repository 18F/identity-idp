module UserProfile
  class ProfileIndex
    attr_reader :decrypted_pii, :recovery_code, :has_password_reset_profile

    def initialize(decrypted_pii:, recovery_code:, current_user:)
      @decrypted_pii = decrypted_pii
      @recovery_code = recovery_code
      @has_password_reset_profile = current_user.password_reset_profile.present?
    end

    def reactivation_instructions_partial
      if has_password_reset_profile
        'profile/reactivation_instructions'
      else
        'shared/null'
      end
    end

    def pii_partial
      if decrypted_pii
        'profile/verified_profile_information'
      else
        'shared/null'
      end
    end

    def recovery_code_warning_partial
      if recovery_code
        'profile/recovery_code_warning'
      else
        'shared/null'
      end
    end
  end
end
