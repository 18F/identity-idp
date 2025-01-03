require 'rails_helper'
load Rails.root.join('bin/summarize-user-events')

RSpec.describe SummarizeUserEvents do
  let(:user_uuid) { nil }
  let(:start_time) { nil }
  let(:end_time) { nil }
  let(:zone) { 'UTC' }

  subject(:instance) do
    described_class.new(
      file_name: nil,
      user_uuid:,
      start_time:,
      end_time:,
      zone: 'UTC',
    )
  end

  describe '#normalize_event!' do
    let(:event) do
      {
        'name' => 'test event',
        '@timestamp' => '2024-12-31 21:21:47.374',
        '@message' => {
          '@timestamp' => '2024-12-31 21:21:47.374',
          'name' => 'test event',
        },
      }
    end

    subject(:normalized_event) do
      event.dup.tap do |event|
        instance.normalize_event!(event)
      end
    end

    context 'when @message is a string' do
      let(:event) do
        super().tap do |event|
          event['@message'] = JSON.generate(event['@message'])
        end
      end
      it 'parses @message as JSON' do
        expect(event['@message']).to be_a(String)
        expect(normalized_event['@message']).to eql(
          '@timestamp' => '2024-12-31 21:21:47.374',
          'name' => 'test event',
        )
      end
    end

    context 'when @timestamp is a string' do
      it 'parses it in UTC' do
        expected = Time.zone.parse('2024-12-31 21:21:47.374 UTC')
        Time.use_zone('America/Los_Angeles') do
          expect(normalized_event['@timestamp']).to eql(expected)
        end
      end
    end
  end
end
