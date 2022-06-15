class AdditionalMfaRequiredController < ApplicationController
    

    before_action :authenticate_user
    before_action :confirm_two_factor_authenticated
    before_action :multiple_factors_enabled?
  
    def show
      
    end
  
    def skip
    end
  
    private
  
    def enforce_second_mfa?
      IdentityConfig.store.select_multiple_mfa_options &&
        MfaContext.new(current_user).enabled_non_restricted_mfa_methods_count < 1
    end
  
    def next_path
      return second_mfa_setup_non_restricted_path
    end
  end
  