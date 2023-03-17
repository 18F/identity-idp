require 'spec_helper'
require 'reporting/cloudwatch_client'

RSpec.describe Reporting::CloudwatchClient do
  let(:wait_duration) { 0 }
  let(:logger) { Logger.new('/dev/null') }
  let(:slice_interval) { 1.day }
  let(:query) { 'fields @message, @timestamp | limit 10000' }

  subject(:client) do
    Reporting::CloudwatchClient.new(
      wait_duration: wait_duration,
      logger: logger,
      slice_interval: slice_interval,
    )
  end

  describe '#fetch' do
    let(:from) { 3.days.ago }
    let(:to) { 1.day.ago }
    let(:now) { Time.zone.now }
    let(:slice_interval) { false }

    subject(:fetch) { client.fetch(query:, from:, to:) }

    # Helps mimic Array<Aws::CloudWatchLogs::Types::ResultField>
    # @return [Array<Hash>]
    def to_result_fields(hsh)
      hsh.map do |key, value|
        { field: key, value: value }
      end
    end

    before do
      stubbed_aws_sdk_client = Aws::CloudWatchLogs::Client.new(stub_responses: true)

      query_id = SecureRandom.hex

      stubbed_aws_sdk_client.stub_responses(:start_query, { query_id: query_id })
      stubbed_aws_sdk_client.stub_responses(
        :get_query_results,
        {
          status: 'Complete',
          results: [
            # rubocop:disable Layout/LineLength
            to_result_fields('@message' => 'aaa', '@timestamp' => now.iso8601, '@ptr' => SecureRandom.hex),
            to_result_fields('@message' => 'bbb', '@timestamp' => now.iso8601, '@ptr' => SecureRandom.hex),
            to_result_fields('@message' => 'ccc', '@timestamp' => now.iso8601, '@ptr' => SecureRandom.hex),
            to_result_fields('@message' => 'ddd', '@timestamp' => now.iso8601, '@ptr' => SecureRandom.hex),
            # rubocop:enable Layout/LineLength
          ],
        },
      )

      allow(client).to receive(:cloudwatch_client).and_return(stubbed_aws_sdk_client)
    end

    context ':slice_interval is falsy' do
      let(:slice_interval) { false }
      it 'does not split up the interval and queries by the from/to passed in' do
        expect(client).to receive(:fetch_one).exactly(1).times.and_call_original

        fetch
      end
    end

    context ':slice_interval is an interval' do
      let(:slice_interval) { 2.days }
      it 'splits the query up into the time range' do
        expect(client).to receive(:fetch_one).exactly(2).times.and_call_original

        fetch
      end
    end

    it 'converts results into hashes, without @ptr' do
      results = fetch

      expect(results).to match_array(
        [
          { '@message' => 'aaa', '@timestamp' => now.iso8601 },
          { '@message' => 'bbb', '@timestamp' => now.iso8601 },
          { '@message' => 'ccc', '@timestamp' => now.iso8601 },
          { '@message' => 'ddd', '@timestamp' => now.iso8601 },
        ],
      )
    end
  end
end
