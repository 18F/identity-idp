module Db
  module AuthAppConfiguration
    class Create
      def self.call(user, otp_secret_key, name = Time.zone.now.to_s)
        user.save
        user.auth_app_configurations.create(otp_secret_key: otp_secret_key, name: name)
      end
    end
  end
end
