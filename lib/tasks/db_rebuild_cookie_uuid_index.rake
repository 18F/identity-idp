namespace :db do
  desc 'Tear down and recreate the cookie_uuid index on devices'
  task rebuild_cookie_uuid_index: :environment do
    ## Set statement timeout to 1 hour
    ActiveRecord::Base.connection.execute('SET statement_timeout = 3600000')

    ## First, delete the old, invalid index if it exists
    existing_index_result = ActiveRecord::Base.connection.execute(
      "SELECT indexname FROM pg_indexes WHERE indexname = 'index_devices_on_cookie_uuid'",
    )
    if existing_index_result.num_tuples > 0
      puts 'Index index_devices_on_cookie_uuid exists, dropping...'
      ActiveRecord::Base.connection.execute('DROP INDEX CONCURRENTLY index_devices_on_cookie_uuid')
    end

    ## Run the SQL from the migration to create the new index
    puts 'Creating new index_devices_on_cookie_uuid index'
    ActiveRecord::Base.connection.execute(
      'CREATE INDEX CONCURRENTLY "index_devices_on_cookie_uuid" ON "devices" ("cookie_uuid")',
    )
  end

  desc 'Check for an invalid cookie_uuid index on devices and print the result'
  task check_for_invalid_cookie_uuid_index: :environment do
    query = <<~SQL
      SELECT * FROM pg_class, pg_index
      WHERE pg_index.indisvalid = false
        AND pg_index.indexrelid = pg_class.oid
        AND pg_class.relname = 'index_devices_on_cookie_uuid'
    SQL
    results = ActiveRecord::Base.connection.execute(query)

    puts "Found #{results.num_tuples} invalid index(es)"
  end
end
