module TwoFactorAuthentication
  class AuthAppPolicy
    def initialize(user)
      @user = user
    end

    def configured?
      user.otp_secret_key.present?
    end

    def available?
      !configured?
    end

    def enabled?
      configured?
    end

    def visible?
      true
    end

    def enrollable?
      available? && !enabled?
    end

    private

    attr_reader :user
  end
end
