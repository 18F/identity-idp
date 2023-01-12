module TwoFactorAuthentication
  class OtpExpiredController < ApplicationController
    def show
      @presenter = presenter_for_two_factor_authentication_method 
    end
  end
end
