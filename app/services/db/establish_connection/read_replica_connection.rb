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
        {
          adapter: 'postgresql',
          database: database_name,
          host: IdentityConfig.store.database_read_replica_host,
          username: IdentityConfig.store.database_readonly_username,
          password: IdentityConfig.store.database_readonly_password,
        }
      end

      def primary_connection_params
        {
          adapter: 'postgresql',
          database: database_name,
          host: IdentityConfig.store.database_host,
          username: IdentityConfig.store.database_username,
          password: IdentityConfig.store.database_password,
        }
      end

      def database_name
        if Rails.env.production?
          IdentityConfig.store.database_name
        else
          "upaya_#{Rails.env}"
        end
      end
    end
  end
end
