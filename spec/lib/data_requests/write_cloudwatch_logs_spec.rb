require 'rails_helper'

RSpec.describe DataRequests::WriteCloudwatchLogs do
  let(:now) { Time.zone.now }

  def build_result_row(event_properties = {})
    DataRequests::FetchCloudwatchLogs::ResultRow.new(
      Time.zone.now,
      {
        time: now.iso8601,
        name: 'Some Log: Event',
        properties: {
          event_properties: {
            success: true,
            multi_factor_auth_method: 'sms',
            phone_configuration_id: '12345',
          }.merge(event_properties),
          service_provider: 'some:service:provider',
          user_ip: '0.0.0.0',
          user_agent: 'Chrome',
        },
      }.to_json,
    )
  end

  let(:cloudwatch_results) do
    [
      build_result_row,
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

      row = CSV.read(File.join(@output_dir, 'logs.csv'), headers: true).first

      expect(row['timestamp']).to eq(now.iso8601)
      expect(row['event_name']).to eq('Some Log: Event')
      expect(row['success']).to eq('true')
      expect(row['multi_factor_auth_method']).to eq('sms')
      expect(row['multi_factor_id']).to eq('phone_configuration_id:12345')
      expect(row['service_provider']).to eq('some:service:provider')
      expect(row['ip_address']).to eq('0.0.0.0')
      expect(row['user_agent']).to eq('Chrome')
    end

    context 'missing data' do
      let(:cloudwatch_results) do
        [
          DataRequests::FetchCloudwatchLogs::ResultRow.new(now, {}.to_json),
        ]
      end

      it 'does not blow up' do
        expect { writer.call }.to_not raise_error
      end
    end

    context 'various multi factor ids' do
      let(:cloudwatch_results) do
        [
          build_result_row(multi_factor_auth_method: 'sms', phone_configuration_id: '1111'),
          build_result_row(multi_factor_auth_method: 'voice', phone_configuration_id: '2222'),
          build_result_row(multi_factor_auth_method: 'piv_cac', piv_cac_configuration_id: '3333'),
          build_result_row(multi_factor_auth_method: 'webauthn', webauthn_configuration_id: '4444'),
          build_result_row(multi_factor_auth_method: 'totp', auth_app_configuration_id: '5555'),
        ]
      end

      it 'unpacks all multi factor ids' do
        writer.call

        csv = CSV.read(File.join(@output_dir, 'logs.csv'), headers: true)

        expect(csv.map { |row| [row['multi_factor_auth_method'], row['multi_factor_id']] }).
          to eq(
            [%w[sms phone_configuration_id:1111],
             %w[voice phone_configuration_id:2222],
             %w[piv_cac piv_cac_configuration_id:3333],
             %w[webauthn webauthn_configuration_id:4444],
             %w[totp auth_app_configuration_id:5555]],
          )
      end
    end
  end
end
