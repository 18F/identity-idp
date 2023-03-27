require 'rails_helper'
require 'reporting/cloudwatch_client'

RSpec.describe Reporting::CloudwatchClient do
  let(:wait_duration) { 0 }
  let(:logger_io) { StringIO.new }
  let(:logger) { Logger.new(logger_io) }
  let(:slice_interval) { 1.day }
  let(:ensure_complete_logs) { false }
  let(:query) { 'fields @message, @timestamp | limit 10000' }
  let(:progress) { false }

  subject(:client) do
    Reporting::CloudwatchClient.new(
      wait_duration:,
      logger:,
      slice_interval:,
      ensure_complete_logs:,
      progress:,
    )
  end

  describe '#fetch' do
    let(:from) { 3.days.ago }
    let(:to) { 1.day.ago }
    let(:now) { Time.zone.now }
    let(:slice_interval) { false }
    let(:time_slices) { nil }

    subject(:fetch) { client.fetch(query:, from:, to:, time_slices:) }

    # Helps mimic Array<Aws::CloudWatchLogs::Types::ResultField>
    # @return [Array<Hash>]
    def to_result_fields(hsh)
      hsh.map do |key, value|
        { field: key, value: value }
      end
    end

    def stub_single_page
      query_id = SecureRandom.hex

      Aws.config[:cloudwatchlogs] = {
        stub_responses: {
          start_query: { query_id: query_id },
          get_query_results: {
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
        },
      }
    end

    context ':slice_interval is falsy' do
      before { stub_single_page }

      let(:slice_interval) { false }
      it 'does not split up the interval and queries by the from/to passed in' do
        expect(client).to receive(:fetch_one).exactly(1).times.and_call_original

        fetch
      end
    end

    context ':slice_interval is a duration' do
      before { stub_single_page }

      let(:slice_interval) { 2.days }

      it 'splits the query up into the time range' do
        expect(client).to receive(:fetch_one).exactly(2).times.and_call_original

        fetch
      end
    end

    context ':time_slices is an array' do
      before { stub_single_page }

      let(:to) { nil }
      let(:from) { nil }
      let(:time_slices) { [1..2, 3..4, 5..6] }

      it 'uses the slices directly' do
        expect(client).to receive(:fetch_one).
          with(hash_including(start_time: 1, end_time: 2)).and_call_original
        expect(client).to receive(:fetch_one).
          with(hash_including(start_time: 3, end_time: 4)).and_call_original
        expect(client).to receive(:fetch_one).
          with(hash_including(start_time: 5, end_time: 6)).and_call_original

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

    it 'yields each row to the block and returns nil with a block' do
      stub_single_page

      results = []
      direct_return = client.fetch(query:, from:, to:, time_slices:) do |row|
        results << row
      end

      expect(direct_return).to be_nil
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
        Aws.config[:cloudwatchlogs] = {
          stub_responses: {
            start_query: proc do |context|
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
            get_query_results: proc do |context|
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
          },
        }
      end

      it 'slices by interval and recurses as needed to get full results' do
        results = fetch

        expect(results.size).to eq(999)
      end
    end

    context 'query is before Cloudwatch Insights Availability and AWS errors' do
      before do
        Aws.config[:cloudwatchlogs] = {
          stub_responses: {
            start_query: Aws::CloudWatchLogs::Errors::InvalidParameterException.new(
              nil,
              'End time should not be before the service was generally available',
            ),
          },
        }
      end

      it 'logs a warning and returns an empty array for that range' do
        expect(fetch).to eq([])

        expect(logger_io.string).to include('is before Cloudwatch Insights availability')
      end
    end
  end
end
