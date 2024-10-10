require 'aws-sdk-s3'
require 'csv'

class DwStaleDataCheckJob < ApplicationJob
  def perform(timestamp)
    data = fetch_table_max_ids_and_counts(timestamp)
    upload_to_s3(data, timestamp)
  end

  private

  def fetch_table_max_ids_and_counts(timestamp)
    active_tables = {}
    retries = 2

    begin
      ActiveRecord::Base.connection.tables.each do |table|
        columns = ActiveRecord::Base.connection.columns(table).map(&:name)
        if columns.include?('id')
          query = "SELECT MAX(id) AS max_id, COUNT(*) AS row_count FROM #{table}"
          query += " WHERE created_at <= '#{timestamp}'" if columns.include?('created_at')
          result = ActiveRecord::Base.connection.execute(query).first
          active_tables[table] = { max_id: result['max_id'], row_count: result['row_count'] }
        end
      end
    rescue => e
      retries -= 1
      if retries > 0
        sleep(2)
        retry
      else
        raise "Failed to fetch table max ids and counts after 2 attempts: #{e.message}"
      end
    end

    active_tables
  end

  def upload_to_s3(data, timestamp)
    date_str = timestamp.strftime('%Y-%m-%d')
    json_data = data.to_json
    s3_client = JobHelpers::S3Helper.new.s3_client
    s3_client.put_object(
      bucket: "login-gov-analytics-export-#{Identity::Hostdata.env}-#{Identity::Hostdata.aws_account_id}-#{Identity::Hostdata.aws_region}",
      key: "idp_max_ids/#{date_str}_idp_max_ids.json",
      body: json_data,
    )
  end
end
