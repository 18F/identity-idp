module TwoFactorAuthentication
  class PivCacPolicy
    def initialize(user)
      @user = user
    end

    def configured?
      user&.x509_dn_uuid.present? || user&.piv_cac_configurations.any?
    end

    def enabled?
      configured?
    end

    def available?
      !enabled?
    end

    def visible?
      enabled? || available?
    end

    private

    attr_reader :user
  end
end
