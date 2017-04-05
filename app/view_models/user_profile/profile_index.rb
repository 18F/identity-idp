module UserProfile
  class ProfileIndex
    attr_reader :decrypted_pii, :recovery_code, :has_password_reset_profile

    def initialize(decrypted_pii:, recovery_code:, has_password_reset_profile:)
      @decrypted_pii = decrypted_pii
      @recovery_code = recovery_code
      @has_password_reset_profile = has_password_reset_profile
    end
  end
end
