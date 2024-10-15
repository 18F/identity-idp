# frozen_string_literal: true

module DataWarehouse
  class DailySensitiveColumnJob < BaseJob
    REPORT_NAME = 'daily-sensitive-column-job'

    def perform(timestamp)
      data = fetch_columns
      upload_to_s3(data, timestamp)
    end

    def fetch_columns
      tables = ActiveRecord::Base.connection.tables - %w[schema_migrations ar_internal_metadata]

      tables.each do |table|
        true_sensitives, false_sensitives = ActiveRecord::Base.connection.columns(table).
          reject { |col| col.name == 'id' }.partition do |column|
          column.comment&.match?(/sensitive=true/i)
        end
        insensitive_hash << false_sensitives.flat_map do |column|
          {
            object_locator: {
              column_name: column.name,
              table_name: table,
            },
          }
        end
        sensitive_hash << true_sensitives.flat_map do |column|
          {
            object_locator: {
              column_name: column.name,
              table_name: table,
            },
          }
        end
      end
      { sensitive: sensitive_hash, insensitive: insensitive_hash }.to_json
    end

    def insensitive_hash
      @insensitive_hash ||= []
      @insensitive_hash = @insensitive_hash.flatten.each do |column|
        column.deep_transform_keys! { |key| key.to_s.tr('_', '-') }
      end
    end

    def sensitive_hash
      @sensitive_hash ||= []
      @sensitive_hash = @sensitive_hash.flatten.each do |column|
        column.deep_transform_keys! { |key| key.to_s.tr('_', '-') }
      end
    end

    def upload_to_s3(body, timestamp)
      _latest, path = generate_s3_paths(REPORT_NAME, 'json', now: timestamp)

      if bucket_name.present?
        upload_file_to_s3_bucket(
          path: path,
          body: body,
          content_type: 'application/json',
          bucket: bucket_name,
        )
      end
    end
  end
end
