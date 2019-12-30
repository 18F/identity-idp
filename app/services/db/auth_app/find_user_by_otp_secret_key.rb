module Db
  module AuthAppConfiguration
    class FindUserByOtpSecretKey
      def self.call(otp_secret_key)
        auth_app_config = ::AuthAppConfiguration.find_by(otp_secret_key: otp_secret_key)
        auth_app_config&.user
      end
    end
  end
end
