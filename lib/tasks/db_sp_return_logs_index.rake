# frozen_string_literal: true

namespace :db do
  desc 'Tear down and recreate the sp_return_logs index'
  task rebuild_sp_return_logs_index: :environment do
    ## Set statement timeout to 1 hour
    ActiveRecord::Base.connection.execute('SET statement_timeout = 3600000')

    ## First, delete the old, invalid index if it exists
    existing_index_result = ActiveRecord::Base.connection.execute <<~SQL
      SELECT indexname
      FROM pg_indexes
      WHERE indexname = 'index_sp_return_logs_on_requested_at_date_issuer'
    SQL
    if existing_index_result.num_tuples > 0
      puts 'Index index_sp_return_logs_on_requested_at_date_issuer exists, dropping...'
      ActiveRecord::Base.connection.execute <<~SQL
        DROP INDEX CONCURRENTLY index_sp_return_logs_on_requested_at_date_issuer
      SQL
    end

    ## Run the SQL from the migration to create the new index
    puts 'Creating new index_sp_return_logs_on_requested_at_date_issuer index'
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX CONCURRENTLY index_sp_return_logs_on_requested_at_date_issuer
      ON public.sp_return_logs
      USING btree ((requested_at::date), issuer)
      WHERE (returned_at IS NOT NULL)
    SQL
  end

  desc 'Check for an invalid sp_return_logs index and print the result'
  task check_for_invalid_sp_return_logs_index: :environment do
    results = ActiveRecord::Base.connection.execute <<~SQL
      SELECT * FROM pg_class, pg_index
      WHERE pg_index.indisvalid = false
        AND pg_index.indexrelid = pg_class.oid
        AND pg_class.relname = 'index_sp_return_logs_on_requested_at_date_issuer'
    SQL

    puts "Found #{results.num_tuples} invalid index(es)"
  end
end
