module Devise
  module TwoFactorAuthenticationHelper
    def two_factor_preference
      if UserOtpSender.new(current_user).otp_should_only_go_to_mobile? || both_options_at_sign_up
        return current_user.unconfirmed_mobile
      end

      second_factors = current_user.second_factors.pluck(:name)

      second_factors.map { |sf| current_user.send(sf.downcase) }.join(' and ')
    end

    def otp_drift_time_in_minutes
      Devise.allowed_otp_drift_seconds / 60
    end

    def both_options_at_sign_up
      current_user.second_factors.size > 1 && current_user.second_factor_confirmed_at.nil?
    end
  end
end
