module Idv
  module VendorValidated
    extend ActiveSupport::Concern

    def vendor_validate
      raise NotImplementedError "Must implement vendor_validate method for #{self}"
    end

    def vendor_validator_class
      raise NotImplementedError "Must implement vendor_validator_class method for #{self}"
    end

    def vendor_params
      raise NotImplementedError "Must implement vendor_params method for #{self}"
    end

    def vendor_errors
      raise NotImplementedError "Must implement vendor_errors method for #{self}"
    end
  end
end
