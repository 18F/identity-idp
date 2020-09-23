module DocAuth
  module Client
    def self.client
      case doc_auth_vendor
      when 'acuant'
        DocAuth::Acuant::AcuantClient.new
      when 'lexisnexis'
        DocAuth::LexisNexis::LexisNexisClient.new
      when 'mock'
        DocAuth::Mock::DocAuthMockClient.new
      else
        raise "#{doc_auth_vendor} is not a valid doc auth vendor"
      end
    end

    ##
    # The `acuant_simulator` config is deprecated. The logic to switch vendors
    # based on its value can be removed once FORCE_ACUANT_CONFIG_UPGRADE in
    # acuant_simulator_config_validation.rb has been set to true for at least
    # a deploy cycle.
    #
    def self.doc_auth_vendor
      vendor_from_config = Figaro.env.doc_auth_vendor
      if vendor_from_config.blank?
        return Figaro.env.acuant_simulator == 'true' ? 'mock' : 'acuant'
      end
      vendor_from_config
    end
  end
end
