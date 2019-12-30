module Db
  module AuthAppConfiguration
    class Create
      def self.call(user_id, otp_secret_key, name = Time.zone.now.to_s)
        ::AuthAppConfiguration.create!(user_id: user_id, otp_secret_key: otp_secret_key, name: name)
      end
    end
  end
end
