module Db
  module EstablishConnection
    class ReadReplicaConnection
      def call
        return yield if Rails.env.test?
        begin
          ActiveRecord::Base.establish_connection(read_replica_connection_params)
          yield
        ensure
          ActiveRecord::Base.establish_connection(primary_connection_params)
        end
      end

      private

      def read_replica_connection_params
        rails_env = Rails.env
        env = AppConfig.env
        {
          adapter: 'postgresql',
          database: rails_env.production? ? env.database_name : "upaya_#{rails_env}",
          host: env.database_read_replica_host,
          username: env.database_readonly_username,
          password: env.database_readonly_password,
        }
      end

      def primary_connection_params
        rails_env = Rails.env
        env = AppConfig.env
        {
          adapter: 'postgresql',
          database: rails_env.production? ? env.database_name : "upaya_#{rails_env}",
          host: env.database_host,
          username: env.database_username,
          password: env.database_password,
        }
      end
    end
  end
end
