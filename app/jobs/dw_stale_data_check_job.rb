require 'aws-sdk-s3'
require 'csv'

class DwStaleDataCheck < ApplicationJob

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
    s3 = Aws::S3::Resource.new(region: 'us-west-2')
    date_str = timestamp.strftime('%Y-%m-%d')
    csv_data = CSV.generate(headers: true) do |csv|
      csv << ['table_name', 'max_id', 'row_count']
      data.each do |table, values|
        csv << [table, values[:max_id], values[:row_count]]
      end
    end
    obj = s3.bucket("login-gov-analytics-export-#{Identity::Hostdata.env}-#{Identity::Hostdata.aws_account_id}-#{Identity::Hostdata.aws_region}").object("idp_max_ids/#{date_str}_idp_max_ids.csv")
    obj.put(body: csv_data)
  end
end