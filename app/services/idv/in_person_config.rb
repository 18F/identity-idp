module Idv
  class InPersonConfig
    def self.enabled_for_issuer?(issuer)
      return false if !enabled?

      if issuer.nil?
        enabled_without_issuer?
      else
        db_enabled = issuer_enabled_db?(issuer)

        if db_enabled.nil?
          enabled_issuers.include?(issuer)
        else
          db_enabled
        end
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

    def self.issuer_enabled_db?(issuer)
      ServiceProvider.find_by(issuer: issuer)&.in_person_proofing_enabled
    end
  end
end
