module Deploy
  module MigrationStatementTimeout
    def connection
      connection = super
      new_statement_timeout = ENV['MIGRATION_STATEMENT_TIMEOUT']
      if new_statement_timeout && !@migration_statement_timeout_set
        connection.execute("SET statement_timeout = #{new_statement_timeout.to_i}")
        @migration_statement_timeout_set = true
      end
      connection
    end
  end
end
