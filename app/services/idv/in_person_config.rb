module Idv
  class InPersonConfig
    def self.enabled_for_issuer?(issuer)
      return false if !enabled?

      if issuer.nil?
        enabled_without_issuer?
      else
        enabled_issuers.include?(issuer)
      end
    end

    def self.enabled_without_issuer?
      !IdentityConfig.store.idv_sp_required
    end

    def self.enabled?
      IdentityConfig.store.in_person_proofing_enabled
    end

    def self.enabled_issuers
      IdentityConfig.store.in_person_proofing_enabled_issuers
    end
  end
end
