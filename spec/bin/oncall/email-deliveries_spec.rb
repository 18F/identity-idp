require 'rails_helper'
load Rails.root.join('bin/oncall/email-deliveries')
require 'tableparser'

RSpec.describe EmailDeliveries do
  describe '.parse!' do
    let(:out) { StringIO.new }
    subject(:parse!) { EmailDeliveries.parse!(argv: argv, out: out) }

    context 'with --help' do
      let(:argv) { %w[--help] }

      it 'prints help and exits uncleanly' do
        expect(EmailDeliveries).to receive(:exit).with(1)

        parse!

        expect(out.string).to include('Usage:')
      end
    end

    context 'with no arguments' do
      let(:argv) { [] }

      it 'prints help and exits uncleanly' do
        expect(EmailDeliveries).to receive(:exit).with(1)

        parse!

        expect(out.string).to include('Usage:')
      end
    end

    context 'with arguments' do
      let(:argv) { %w[abc def] }

      it 'returns an instance populated with UUIDs' do
        expect(parse!.uuids).to eq(%w[abc def])
      end
    end
  end

  describe '#run' do
    let(:instance) { EmailDeliveries.new(uuids: %w[abc123 def456], progress_bar: false) }
    let(:stdout) { StringIO.new }
    subject(:run) { instance.run(out: stdout) }

    before do
      allow(instance).to receive(:cloudwatch_client).
        with('prod_/srv/idp/shared/log/events.log').
        and_return(instance_double('Reporting::CloudwatchClient', fetch: events_log))

      allow(instance).to receive(:cloudwatch_client).
        with('/aws/lambda/SESAllEvents_Lambda').
        and_return(instance_double('Reporting::CloudwatchClient', fetch: email_events))
    end

    # rubocop:disable Layout/LineLength
    let(:events_log) do
      [
        { '@timestamp' => '2023-01-01 00:00:01', 'user_id' => 'abc123', 'email_action' => 'forgot_password', 'ses_message_id' => 'message-1' },
        { '@timestamp' => '2023-01-01 00:00:02', 'user_id' => 'def456', 'email_action' => 'forgot_password', 'ses_message_id' => 'message-2' },
      ]
    end

    let(:email_events) do
      [
        { '@timestamp' => '2023-01-01 00:00:01', 'ses_message_id' => 'message-1', 'event_type' => 'Send' },
        { '@timestamp' => '2023-01-01 00:00:02', 'ses_message_id' => 'message-1', 'event_type' => 'Delivery' },
        { '@timestamp' => '2023-01-01 00:00:03', 'ses_message_id' => 'message-2', 'event_type' => 'Send' },
        { '@timestamp' => '2023-01-01 00:00:04', 'ses_message_id' => 'message-2', 'event_type' => 'Bounce', 'bounce_type' => 'Transient', 'bounce_sub_type' => 'MailboxFull' },
      ]
    end
    # rubocop:enable Layout/LineLength

    it 'prints a table of events by message ID' do
      run

      table = Tableparser.parse(stdout.string)

      expect(table).to eq(
        [
          ['user_id', 'timestamp', 'message_id', 'email_action', 'events'],
          ['abc123', '2023-01-01 00:00:01', 'message-1', 'forgot_password', 'Send, Delivery'],
          ['def456', '2023-01-01 00:00:02', 'message-2', 'forgot_password',
           'Send, Bounce-Transient-MailboxFull'],
        ],
      )
    end
  end
end
