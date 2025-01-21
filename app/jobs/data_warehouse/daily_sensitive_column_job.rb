# frozen_string_literal: true

module DataWarehouse
  class DailySensitiveColumnJob < BaseJob
    REPORT_NAME = 'daily-sensitive-column-job'

    def perform(timestamp)
      data = fetch_columns

      if IdentityConfig.store.s3_idp_dw_tasks.present?
        upload_to_s3(data, timestamp)
      end
    end

    def fetch_columns
      tables = ActiveRecord::Base.connection.tables - %w[schema_migrations ar_internal_metadata
                                                         awsdms_ddl_audit]

      sensitive_hash = []
      insensitive_hash = []

      tables.each do |table|
        true_sensitives, false_sensitives = ActiveRecord::Base.connection.columns(table)
          .reject { |col| col.name == 'id' }
          .partition do |column|
            column.comment&.match?(/sensitive=true/i)
          end
        insensitive_hash.concat(generate_column_data(false_sensitives, table))
        sensitive_hash.concat(generate_column_data(true_sensitives, table))
      end
      {
        sensitive: sensitive_hash,
        insensitive: insensitive_hash,
      }.to_json
    end

    def generate_column_data(columns, table)
      columns.map do |column|
        {
          "object-locator": {
            "column-name": column.name,
            "table-name": table,
          },
        }
      end
    end

    def bucket_name
      bucket_name = IdentityConfig.store.s3_idp_dw_tasks
      env = Identity::Hostdata.env
      aws_account_id = Identity::Hostdata.aws_account_id
      aws_region = Identity::Hostdata.aws_region
      "#{bucket_name}-#{env}-#{aws_account_id}-#{aws_region}"
    end

    def upload_to_s3(body, timestamp)
      _latest, path = generate_s3_paths(REPORT_NAME, 'json', now: timestamp)

      upload_file_to_s3_bucket(
        path: path,
        body: body,
        content_type: 'application/json',
        bucket: bucket_name,
      )
    end
  end
end
