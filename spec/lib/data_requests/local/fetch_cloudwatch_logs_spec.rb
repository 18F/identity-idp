require 'rails_helper'
require 'data_requests/local'

RSpec.describe DataRequests::Local::FetchCloudwatchLogs do
  let(:uuid) { 'super-fun-but-fake-uuid' }
  it 'starts queries for each date and returns processed results' do
    dates = [
      Date.new(2020, 3, 18),
      Date.new(2020, 8, 7),
    ]

    Aws.config[:cloudwatchlogs] = {
      stub_responses: {
        start_query: [
          { query_id: '123abc' },
          { query_id: '456def' },
        ],
        get_query_results: [
          { status: 'Running' },
          { status: 'Running' },
          {
            status: 'Complete',
            results: [
              [
                { field: '@timestamp', value: 'timestamp-1' },
                { field: '@message', value: 'message-1' },
              ],
            ],
          },
          {
            status: 'Complete',
            results: [
              [
                { field: '@timestamp', value: 'timestamp-2' },
                { field: '@message', value: 'message-2' },
              ],
            ],
          },
        ],
      },
    }

    cloudwatch_client_options = {
      num_threads: 1,
      wait_duration: 0,
      progress: false,
    }

    subject = described_class.new(uuid, dates, cloudwatch_client_options:)

    results = subject.call

    expect(results.length).to eq(2)
    expect(results.first.timestamp).to eq('timestamp-1')
    expect(results.first.message).to eq('message-1')
    expect(results.second.timestamp).to eq('timestamp-2')
    expect(results.second.message).to eq('message-2')
  end

  it 'fails if run in a deployed environment' do
    allow(Identity::Hostdata).to receive(:in_datacenter?).and_return(true)

    expect do
      described_class.new('fake-uuid', []).call
    end.to raise_error('Only run DataRequests::Local::FetchCloudwatchLogs locally')
  end

  describe '#query_ranges' do
    subject(:query_ranges) do
      described_class.new(uuid, dates).query_ranges
    end

    context 'with a bunch of consecutive days' do
      let(:dates) do
        [
          Date.new(2023, 1, 1),
          Date.new(2023, 1, 2),
          Date.new(2023, 1, 3),
          # gap
          Date.new(2023, 1, 5),
          Date.new(2023, 1, 6),
          Date.new(2023, 1, 7),
        ]
      end

      it 'groups consecutive days into a single range, and pads by 12 hours' do
        expect(query_ranges).to eq(
          [
            # rubocop:disable Layout/LineLength
            (Date.new(2023, 1, 1).beginning_of_day - 12.hours)..(Date.new(2023, 1, 3).end_of_day + 12.hours),
            (Date.new(2023, 1, 5).beginning_of_day - 12.hours)..(Date.new(2023, 1, 7).end_of_day + 12.hours),
            # rubocop:enable Layout/LineLength
          ],
        )
      end
    end

    context 'with more than 7 consecutive days' do
      let(:dates) do
        [
          Date.new(2023, 1, 1),
          Date.new(2023, 1, 2),
          Date.new(2023, 1, 3),
          Date.new(2023, 1, 4),
          Date.new(2023, 1, 5),
          Date.new(2023, 1, 6),
          Date.new(2023, 1, 7),
          # slice goes here
          Date.new(2023, 1, 8),
          Date.new(2023, 1, 9),
        ]
      end

      it 'splits up consecutive ranges of more than 7 days into adjacent ranges' do
        expect(query_ranges).to eq(
          [
            (Date.new(2023, 1, 1).beginning_of_day - 12.hours)..Date.new(2023, 1, 7).end_of_day,
            Date.new(2023, 1, 8).beginning_of_day..(Date.new(2023, 1, 9).end_of_day + 12.hours),
          ],
        )
      end
    end
  end
end
