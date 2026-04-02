require 'rails_helper'

RSpec.describe Reports::BaseReport do
  subject(:report) { described_class.new }

  before do
    allow(Identity::Hostdata).to receive(:env).and_return('test')
  end

  describe '#transaction_with_timeout' do
    let(:rails_env) { ActiveSupport::StringInquirer.new('production') }
    let(:report_timeout) { 999 }

    before do
      allow(IdentityConfig.store).to receive(:report_timeout).and_return(report_timeout)
    end

    it 'sets the statement_timeout inside a transaction' do
      result = report.send(:transaction_with_timeout, rails_env) do
        ActiveRecord::Base.connection.execute('SHOW statement_timeout')
      end

      expect(result.first['statement_timeout']).to eq("#{report_timeout}ms")
    end
  end

  describe '#generate_s3_paths' do
    let(:report_name) { 'abc_proofing_events_by_uuid' }
    let(:extension) { 'csv' }
    let(:timestamp) { Time.utc(2026, 4, 1, 13, 0, 0) }

    it 'generates the default date-based timestamped path and stable latest path' do
      latest_path, timestamped_path = report.send(
        :generate_s3_paths,
        report_name,
        extension,
        now: timestamp,
      )

      expect(latest_path).to eq('test/abc_proofing_events_by_uuid/latest.abc_proofing_events_by_uuid.csv')
      expect(timestamped_path).to eq(
        'test/abc_proofing_events_by_uuid/2026/2026-04-01.abc_proofing_events_by_uuid.csv',
      )
    end

    it 'generates an hourly timestamped path without changing the latest path' do
      latest_path, timestamped_path = report.send(
        :generate_s3_paths,
        report_name,
        extension,
        now: timestamp,
        timestamp_format: '%F.%H',
      )

      expect(latest_path).to eq('test/abc_proofing_events_by_uuid/latest.abc_proofing_events_by_uuid.csv')
      expect(timestamped_path).to eq(
        'test/abc_proofing_events_by_uuid/2026/2026-04-01.13.abc_proofing_events_by_uuid.csv',
      )
    end
  end
end
