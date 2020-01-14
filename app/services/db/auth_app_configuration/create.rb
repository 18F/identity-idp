module Db
  module AuthAppConfiguration
    class Create
      def self.call(user, otp_secret_key, totp_timestamp, name = Time.zone.now.to_s)
        user.auth_app_configurations.create(otp_secret_key: otp_secret_key,
                                            totp_timestamp: totp_timestamp,
                                            name: name)
      end
    end
  end
end
