# frozen_string_literal: true

module Db
  class PivCacConfiguration
    def self.create(user, x509_dn_uuid, name = x509_dn_uuid, issuer = nil)
      user.piv_cac_configurations.create!(
        x509_dn_uuid: x509_dn_uuid,
        name: name,
        x509_issuer: issuer,
      )
    end

    def self.delete(user_id, cfg_id)
      ::PivCacConfiguration.where(user_id: user_id, id: cfg_id).delete_all
    end

    def self.find_user_by_x509(x509_dn_uuid)
      ::PivCacConfiguration.find_by(x509_dn_uuid: x509_dn_uuid)&.user
    end
  end
end
