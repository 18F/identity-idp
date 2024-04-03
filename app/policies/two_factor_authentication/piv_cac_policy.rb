# frozen_string_literal: true

module TwoFactorAuthentication
  class PivCacPolicy
    def initialize(user)
      @user = user
    end

    def configured?
      user&.piv_cac_configurations&.any?
    end

    def enabled?
      configured?
    end

    private

    attr_reader :user
  end
end
