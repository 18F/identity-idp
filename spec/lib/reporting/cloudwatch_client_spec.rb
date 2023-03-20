require 'rails_helper'
require 'reporting/cloudwatch_client'

RSpec.describe Reporting::CloudwatchClient do
  let(:wait_duration) { 0 }
  let(:logger) { Logger.new('/dev/null') }
  let(:slice_interval) { 1.day }
  let(:ensure_complete_logs) { false }
  let(:query) { 'fields @message, @timestamp | limit 10000' }
  let(:progress) { false }

  subject(:client) do
    Reporting::CloudwatchClient.new(
      wait_duration: wait_duration,
      logger: logger,
      slice_interval: slice_interval,
      ensure_complete_logs: ensure_complete_logs,
      progress: progress,
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

    def stub_single_page
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

      allow(client).to receive(:aws_client).and_return(stubbed_aws_sdk_client)
    end

    context ':slice_interval is falsy' do
      before { stub_single_page }

      let(:slice_interval) { false }
      it 'does not split up the interval and queries by the from/to passed in' do
        expect(client).to receive(:fetch_one).exactly(1).times.and_call_original

        fetch
      end
    end

    context ':slice_interval is an interval' do
      before { stub_single_page }

      let(:slice_interval) { 2.days }
      it 'splits the query up into the time range' do
        expect(client).to receive(:fetch_one).exactly(2).times.and_call_original

        fetch
      end
    end

    it 'converts results into hashes, without @ptr' do
      stub_single_page

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

    context ':progress' do
      let(:progress) { StringIO.new }

      it 'logs a progress bar to the given IO' do
        stub_single_page

        fetch

        expect(progress.string).to include('=====')
      end
    end

    context ':ensure_complete_logs is true' do
      let(:slice_interval) { 500 }
      let(:ensure_complete_logs) { true }
      let(:from) { Time.zone.at(1) }
      let(:to) { Time.zone.at(1000) }

      before do
        stubbed_aws_sdk_client = Aws::CloudWatchLogs::Client.new(stub_responses: true)

        stubbed_aws_sdk_client.stub_responses(
          :start_query,
          proc do |context|
            start_time, end_time = context.params.values_at(:start_time, :end_time)

            query_id = case [start_time, end_time]
            when [1, 500]
              'query_id_too_many_results'
            when [501, 1000], [1, 249], [250, 500]
              'query_id_normal_results'
            else
              raise "no start_query stub for start_time=#{start_time}, end_time=#{end_time}"
            end

            { query_id: }
          end,
        )

        stubbed_aws_sdk_client.stub_responses(
          :get_query_results,
          proc do |context|
            query_id = context.params[:query_id]

            results = case query_id
            when 'query_id_too_many_results'
              10_001.times.map { to_result_fields('@message' => 'aaa') }
            when 'query_id_normal_results'
              333.times.map { to_result_fields('@message' => 'aaa') }
            else
              raise "Unknown query_id=#{query_id}"
            end

            { status: 'Complete', results: }
          end,
        )

        allow(client).to receive(:aws_client).and_return(stubbed_aws_sdk_client)
      end

      it 'slices by interval and recurses as needed to get full results' do
        results = fetch

        expect(results.size).to eq(999)
      end
    end
  end
end
