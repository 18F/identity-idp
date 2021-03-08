require 'rails_helper'
require 'aws-sdk-cloudwatchlogs'

describe DataRequests::FetchCloudwatchLogs do
  it 'starts queries for each date and returns processed results' do
    uuid = 'super-fun-but-fake-uuid'
    dates = [
      Date.new(2020, 3, 18),
      Date.new(2020, 8, 7),
    ]

    mock_cloudwatch_client = Aws::CloudWatchLogs::Client.new(stub_responses: true)
    mock_cloudwatch_client.stub_responses(
      :start_query,
      { query_id: '123abc' },
      { query_id: '456def' },
    )
    mock_cloudwatch_client.stub_responses(
      :get_query_results,
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
    )
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_return(mock_cloudwatch_client)

    subject = described_class.new(uuid, dates)

    allow(subject).to receive(:sleep)
    allow(subject).to receive(:warn)

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
    end.to raise_error('Only run DataRequests::FetchCloudwatchLogs locally')
  end
end
