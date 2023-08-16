require 'rails_helper'
load Rails.root.join('bin/oncall/otp-deliveries')

RSpec.describe OtpDeliveries do
  describe '.parse!' do
    let(:out) { StringIO.new }
    subject(:parse!) { OtpDeliveries.parse!(argv: argv, out: out) }

    context 'with --help' do
      let(:argv) { %w[--help] }

      it 'prints help and exits uncleanly' do
        expect(OtpDeliveries).to receive(:exit).with(1)

        parse!

        expect(out.string).to include('Usage:')
      end
    end

    context 'with no arguments' do
      let(:argv) { [] }

      it 'prints help and exits uncleanly' do
        expect(OtpDeliveries).to receive(:exit).with(1)

        parse!

        expect(out.string).to include('Usage:')
      end
    end

    context 'with arguments' do
      let(:argv) { %w[abc def] }

      it 'returns an instance populated with UUIDs' do
        expect(parse!.uuids).to eq(%w[abc def])
      end

      context 'with --filter' do
        let(:argv) { [*super(), '--filter', 'VOICE'] }

        it 'sets the filter' do
          expect(parse!.filter).to eq('VOICE')
        end
      end

      it 'defaults to table formatting' do
        expect(parse!.output_format).to eq(:table)
      end

      context 'with --csv' do
        let(:argv) { [*super(), '--csv'] }

        it 'outputs CSV' do
          expect(parse!.output_format).to eq(:csv)
        end
      end

      context 'with --json' do
        let(:argv) { [*super(), '--json'] }

        it 'outputs JSON' do
          expect(parse!.output_format).to eq(:json)
        end
      end

      context 'with --table' do
        let(:argv) { [*super(), '--table'] }

        it 'outputs a table' do
          expect(parse!.output_format).to eq(:table)
        end
      end
    end
  end

  describe '#run' do
    let(:instance) do
      OtpDeliveries.new(
        uuids: %w[abc123 def456],
        progress_bar: false,
        output_format: :json,
      )
    end
    let(:stdout) { StringIO.new }
    subject(:run) { instance.run(out: stdout) }

    let(:cloudwatch_client) { instance_double('Reporting::CloudwatchClient') }

    before do
      allow(instance).to receive(:cloudwatch_client).and_return(cloudwatch_client)

      allow(cloudwatch_client).to receive(:fetch).and_return(
        [
          {
            'properties.user_id' => 'aaa',
            '@timestamp' => 'bbb',
            'properties.event_properties.telephony_response.message_id' => 'ccc',
            'properties.event_properties.otp_delivery_preference' => 'sms',
            'properties.event_properties.country_code' => 'US',
          },
        ],
      )
    end

    it 'renders a table of information for debugging otp sends' do
      run

      expect(JSON.parse(stdout.string, symbolize_names: true)).to eq(
        [
          {
            user_id: 'aaa',
            timestamp: 'bbb',
            message_id: 'ccc',
            delivery_preference: 'sms',
            country_code: 'US',
          },
        ],
      )
    end
  end
end
