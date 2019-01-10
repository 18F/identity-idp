module TwoFactorAuthentication
  class PivCacPolicy
    def initialize(user)
      @user = user
    end

    def configured?
      user&.x509_dn_uuid.present?
    end

    def enabled?
      configured?
    end

    def available?
      !enabled? && available_if_not_enabled?
    end

    def visible?
      enabled? || available?
    end

    private

    def available_if_not_enabled?
      if FeatureManagement.allow_piv_cac_by_email_only?
        PivCacService.piv_cac_available_for_email?(user.email_addresses.map(&:email))
      else
        user.identities.any?(&:piv_cac_available?)
      end
    end

    attr_reader :user
  end
end
