module TwoFactorAuthentication
  class AuthAppPolicy
    def initialize(user)
      @user = user
    end

    def configured?
      user&.auth_app_configurations&.any?
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
