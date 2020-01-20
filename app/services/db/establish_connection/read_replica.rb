module Db
  module EstablishConnection
    class ReadReplica
      def self.call
        rails_env = Rails.env
        return if rails_env.test?
        env = Figaro.env
        ActiveRecord::Base.establish_connection(
          adapter: 'postgresql',
          database: env.production? ? env.database_name : "upaya_#{rails_env}",
          host: env.database_read_replica_host,
          username: env.database_readonly_username,
          password: env.database_readonly_password,
        )
      end
    end
  end
end
