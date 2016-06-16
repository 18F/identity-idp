module Devise
  module TwoFactorAuthenticationHelper
    def otp_valid_for_in_words
      distance_of_time_in_words(Devise.direct_otp_valid_for)
    end
  end
end
