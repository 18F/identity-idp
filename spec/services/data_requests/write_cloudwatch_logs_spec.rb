require 'rails_helper'

RSpec.describe DataRequests::WriteCloudwatchLogs do
  let(:now) { Time.zone.now }

  let(:cloudwatch_results) do
    [
      DataRequests::FetchCloudwatchLogs::ResultRow.new(
        Time.zone.now,
        {
          time: now.iso8601,
          name: 'Some Log: Event',
          properties: {
            event_properties: {
              success: true,
              multi_factor_auth_method: 'sms',
            },
            service_provider: 'some:service:provider',
            user_ip: '0.0.0.0',
            user_agent: 'Chrome'
          }
        }.to_json
      )
    ]
  end

  around do |ex|
    Dir.mktmpdir do |dir|
      @output_dir = dir
      ex.run
    end
  end

  subject(:writer) do
    DataRequests::WriteCloudwatchLogs.new(cloudwatch_results, @output_dir)
  end

  describe '#call' do
    it 'writes the logs to output_dir/logs.csv' do
      writer.call

      csv = CSV.read(File.join(@output_dir, 'logs.csv'), headers: true)

      row = csv.first

      expect(row['timestamp']).to eq(now.iso8601)
      expect(row['event_name']).to eq('Some Log: Event')
      expect(row['success']).to eq('true')
      expect(row['multi_factor_auth_method']).to eq('sms')
      expect(row['service_provider']).to eq('some:service:provider')
      expect(row['ip_address']).to eq('0.0.0.0')
      expect(row['user_agent']).to eq('Chrome')
    end
  end
end
