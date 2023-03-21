require 'rails_helper'
require 'reporting/command_line_options'

RSpec.describe Reporting::CommandLineOptions do
  let(:instance) { Reporting::CommandLineOptions.new }
  let(:issuer) { 'my:example:issuer' }

  describe '.parse!' do
    before do
      allow(instance).to receive(:exit)
    end

    let(:stdout) { StringIO.new }
    let(:argv) { [] }

    subject(:parse!) { instance.parse!(argv, out: stdout) }

    context 'with no arguments' do
      let(:argv) { [] }

      it 'prints help and exits uncleanly' do
        expect(instance).to receive(:exit).and_return(1)

        parse!

        expect(stdout.string).to include('Usage:')
      end
    end

    context 'with --help' do
      let(:argv) { %w[--help] }

      it 'prints help and exits uncleanly' do
        expect(instance).to receive(:exit).and_return(1)

        parse!

        expect(stdout.string).to include('Usage:')
      end
    end

    context 'with --date and --issuer' do
      let(:argv) { %W[--date 2023-1-1 --issuer #{issuer}] }

      it 'returns the parsed options' do
        expect(parse!).to match(
          date_range: Date.new(2023, 1, 1).in_time_zone('UTC').all_day,
          issuer: issuer,
          verbose: false,
          progress: true,
        )
      end
    end

    context 'with --week and --issuer' do
      let(:argv) { %W[--week 2023-1-1 --issuer #{issuer}] }

      it 'uses the whole week from sun-sat' do
        sunday = Date.new(2023, 1, 1).in_time_zone('UTC')
        saturday = Date.new(2023, 1, 7).in_time_zone('UTC')

        expect(parse![:date_range]).to eq(sunday.beginning_of_day..saturday.end_of_day)
      end
    end

    context 'with --no-verbose' do
      let(:argv) { %W[--date 2023-1-1 --issuer #{issuer} --no-verbose] }

      it 'has verbose false' do
        expect(parse![:verbose]).to eq(false)
      end
    end

    context 'with --no-progress' do
      let(:argv) { %W[--date 2023-1-1 --issuer #{issuer} --no-progress] }

      it 'has a progress false' do
        expect(parse![:progress]).to eq(false)
      end
    end
  end
end
