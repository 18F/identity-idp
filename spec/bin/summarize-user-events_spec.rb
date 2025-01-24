require 'rails_helper'
load Rails.root.join('bin/summarize-user-events')

RSpec.describe SummarizeUserEvents do
  let(:user_uuid) { nil }
  let(:start_time) { nil }
  let(:end_time) { nil }
  let(:zone) { 'America/New_York' }
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }

  subject(:instance) do
    described_class.new(
      file_name: nil,
      user_uuid:,
      start_time:,
      end_time:,
      zone:,
      stdout:,
      stderr:,
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

  describe '#parse_command_line_options' do
    let(:argv) do
      []
    end

    subject(:parsed) do
      described_class.parse_command_line_options(argv)
    end

    it 'parses default options' do
      expect(parsed).to eql(
        { zone: 'America/New_York' },
      )
    end

    context '-z' do
      let(:argv) { ['-z', 'America/Los_Angeles'] }

      it 'parses zone' do
        expect(parsed).to eql(
          {
            zone: 'America/Los_Angeles',
          },
        )
      end
    end
  end

  describe '#parse_time' do
    let(:input) { nil }

    subject(:actual) do
      instance.parse_time(input)
    end

    context 'with valid UTC timestamp' do
      let(:input) do
        '2025-01-07T19:56:03Z'
      end
      it 'parses it as UTC, then converts to configured zone' do
        expect(actual.to_s).to eql(
          '2025-01-07 14:56:03 -0500',
        )
      end
    end

    context 'with a timestamp with no zone specified' do
      let(:input) do
        '2025-01-07T19:56:03'
      end
      it 'parses it as UTC, then converts to configured zone' do
        expect(actual.to_s).to eql(
          '2025-01-07 14:56:03 -0500',
        )
      end
    end

    context 'with a timestamp with a different zone specified' do
      let(:input) do
        '2025-01-07T19:56:03 -0600'
      end
      it 'parses it as UTC, then converts to configured zone' do
        expect(actual.to_s).to eql(
          '2025-01-07 20:56:03 -0500',
        )
      end
    end

    context 'with an invalid time value' do
      let(:input) { 'not even a time' }
      it 'returns nil' do
        expect(actual).to eql(nil)
      end
    end

    context 'with blank string' do
      let(:input) { '' }
      it 'returns nil' do
        expect(actual).to eql(nil)
      end
    end
  end

  describe '#run' do
    subject(:command_output) do
      instance.run
      stdout.string
    end

    let(:cloudwatch_events) do
      [
        {
          '@timestamp' => '2024-12-30 15:42:51.336',
          '@message' => JSON.generate(
            {
              name: 'IdV: doc auth welcome submitted',
            },
          ),
        },
      ]
    end

    before do
      allow(instance).to receive(:cloudwatch_source) do |&block|
        cloudwatch_events.each do |raw_event|
          block.call(raw_event)
        end
      end
    end

    it 'matches expected output' do
      expect(command_output).to eql(<<~END)
        ## Processed some events
        * Processed 1 event(s)
        
        ## Identity verification started (December 30, 2024 at 10:42 AM EST)
        * (10:42 AM) User abandoned identity verification
      END
    end
  end
end
