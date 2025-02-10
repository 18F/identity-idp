# frozen_string_literal: true

module TwoFactorAuthentication
  class AuthAppPolicy
    def initialize(user)
      @user = user
    end

    def configured?
      user&.auth_app_configurations&.any?
    end

    def enabled?
      configured?
    end

    private

    attr_reader :user
  end
end
