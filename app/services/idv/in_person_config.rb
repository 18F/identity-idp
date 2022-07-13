module Idv
  class InPersonConfig
    def self.enabled_for_issuer?(issuer)
      enabled? && (issuer.nil? || enabled_issuers.include?(issuer))
    end

    def self.enabled?
      IdentityConfig.store.in_person_proofing_enabled
    end

    def self.enabled_issuers
      IdentityConfig.store.in_person_proofing_enabled_issuers
    end
  end
end
