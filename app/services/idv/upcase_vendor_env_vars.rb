module Idv
  class UpcaseVendorEnvVars
    def call
      available_vendors.each do |vendor|
        upcase_env_vars(vendor)
      end
    end

    private

    def available_vendors
      env = Figaro.env
      [
        env.profile_proofing_vendor,
        env.phone_proofing_vendor,
      ]
    end

    def upcase_env_vars(vendor)
      ENV.keys.grep(/^#{vendor}_/).each do |env_var_name|
        ENV[env_var_name.upcase] = ENV[env_var_name]
      end
    end
  end
end
