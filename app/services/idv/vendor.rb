module Idv
  class Vendor
    # Proofer gem will attempt to autoload based on the initializer name
    # so make sure our load path includes whichever vendors we have defined.
    if Figaro.env.proofing_vendors
      Figaro.env.proofing_vendors.split(/\W+/).each do |vendor|
        vendor_path = "#{Rails.root}/vendor/#{vendor}/lib"
        $LOAD_PATH.unshift vendor_path
      end
    end

    def pick
      available.sample
    end

    def available
      @_vendors ||= Figaro.env.proofing_vendors.split(/\W+/).map(&:to_sym)
    end

    def upcase_env_vars
      available.each do |vendor|
        upcase_env_var(vendor)
      end
    end

    private

    def upcase_env_var(vendor)
      ENV.keys.grep(/^#{vendor}_/).each do |env_var_name|
        ENV[env_var_name.upcase] = ENV[env_var_name]
      end
    end
  end
end
