# frozen_string_literal: true

module DataWarehouse
  class StaleDataCheckJob < BaseJob
    REPORT_NAME = 'idp_max_ids'

    def perform(timestamp)
      data = fetch_table_max_ids_and_counts(timestamp)
      upload_to_s3(data, timestamp)
    end

    def fetch_table_max_ids_and_counts(timestamp)
      max_ids_and_counts(timestamp)
    end

    private

    def max_ids_and_counts(timestamp)
      active_tables = {}
      ActiveRecord::Base.connection.tables.each do |table|
        if table_has_id_column?(table)
          active_tables[table] = fetch_max_id_and_count(table, timestamp)
        end
      end

      active_tables
    end

    def table_has_id_column?(table)
      ActiveRecord::Base.connection.columns(table).map(&:name).include?('id')
    end

    def fetch_max_id_and_count(table, timestamp)
      query = <<-SQL
        SELECT COALESCE(MAX(id), 0) AS max_id, COUNT(*) AS row_count
        FROM #{table}
        #{"WHERE created_at <= '#{timestamp}'" if table_has_column?(table, 'created_at')}
      SQL

      ActiveRecord::Base.connection.execute(query).first
    end

    def table_has_column?(table, column_name)
      ActiveRecord::Base.connection.columns(table).map(&:name).include?(column_name)
    end

    def upload_to_s3(data, timestamp)
      _latest, path = generate_s3_paths(REPORT_NAME, 'json', now: timestamp)

      if bucket_name.present?
        upload_file_to_s3_bucket(
          path: path,
          body: data.to_json,
          content_type: 'application/json',
          bucket: bucket_name,
        )
      end
    end
  end
end
