module Idv
  class InPersonConfig
    def self.enabled_for_issuer?(issuer)
      return false if !enabled?

      if issuer.nil?
        enabled_without_issuer?
      else
        ServiceProvider.find_by(issuer: issuer)&.in_person_proofing_enabled || false
      end
    end

    def self.enabled_without_issuer?
      !IdentityConfig.store.idv_sp_required
    end

    def self.enabled?
      IdentityConfig.store.in_person_proofing_enabled
    end
  end
end
