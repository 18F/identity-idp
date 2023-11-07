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
    let(:require_issuer) { true }

    subject(:parse!) { instance.parse!(argv, out: stdout, require_issuer:) }

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
          time_range: Date.new(2023, 1, 1).in_time_zone('UTC').all_day,
          issuers: [issuer],
          verbose: false,
          progress: true,
          slice: 3.hours,
          threads: 5,
        )
      end
    end

    context 'with --date and multiple --issuer tags' do
      let(:argv) { %W[--date 2023-1-1 --issuer #{issuer} --issuer #{issuer2}] }
      let(:issuer2) { 'my:other:example:issuer' }

      it 'returns the parsed options' do
        expect(parse!).to match(
          time_range: Date.new(2023, 1, 1).in_time_zone('UTC').all_day,
          issuers: [issuer, issuer2],
          verbose: false,
          progress: true,
          slice: 3.hours,
          threads: 5,
        )
      end
    end

    context 'missing --issuer' do
      let(:argv) { %w[--date 2023-1-1] }

      it 'prints help and exits uncleanly' do
        expect(instance).to receive(:exit).and_return(1)

        parse!

        expect(stdout.string).to include('Usage:')
      end

      context 'with require_issuer: false' do
        let(:require_issuer) { false }

        it 'returns the parsed options' do
          expect(parse!).to match(
            time_range: Date.new(2023, 1, 1).in_time_zone('UTC').all_day,
            issuers: [],
            verbose: false,
            progress: true,
            slice: 3.hours,
            threads: 5,
          )
        end
      end
    end

    context 'with --week and --issuer' do
      let(:argv) { %W[--week 2023-1-1 --issuer #{issuer}] }

      it 'uses the whole week from sunday 12am to saturday midnight' do
        sunday = Date.new(2023, 1, 1).in_time_zone('UTC')
        expect(sunday).to be_sunday
        saturday = Date.new(2023, 1, 7).in_time_zone('UTC')
        expect(saturday).to be_saturday

        expect(parse![:time_range]).to eq(sunday.beginning_of_day..saturday.end_of_day)
      end
    end

    context 'with --month and --issuer' do
      let(:argv) { %W[--month 2023-1-1 --issuer #{issuer}] }

      it 'uses the whole month given from the first at 12am to the last midnight' do
        jan_1 = Date.new(2023, 1, 1).in_time_zone('UTC')
        jan_last = Date.new(2023, 1, 31).in_time_zone('UTC')

        expect(parse![:time_range]).to eq(jan_1.beginning_of_day..jan_last.end_of_day)
      end

      it 'updates slice to 1.hr if slice is not passed in' do
        expect(parse![:slice]).to eq 1.hour
      end

      it 'updates threads to 10 if threads is not passed in' do
        expect(parse![:threads]).to eq 10
      end
    end

    context 'with --slice' do
      context 'with --slice in minutes' do
        let(:argv) { %W[--slice 2min --month 2023-1-1 --issuer #{issuer}] }

        it 'slice is 2 minutes' do
          expect(parse![:slice]).to eq 2.minutes
        end
      end

      context 'with --slice in hours' do
        let(:argv) { %W[--slice 2h --month 2023-1-1 --issuer #{issuer}] }

        it 'slice is 2 hours' do
          expect(parse![:slice]).to eq 2.hours
        end
      end

      context 'with --slice in days' do
        let(:argv) { %W[--slice 3d --month 2023-1-1 --issuer #{issuer}] }

        it 'slice is 3 days' do
          expect(parse![:slice]).to eq 3.days
        end
      end

      context 'with --slice in weeks' do
        let(:argv) { %W[--slice 3w --month 2023-1-1 --issuer #{issuer}] }

        it 'slice is 3 weeks' do
          expect(parse![:slice]).to eq 3.weeks
        end
      end

      context 'with --slice in months' do
        let(:argv) { %W[--slice 3mon --month 2023-1-1 --issuer #{issuer}] }

        it 'slice is 3 months' do
          expect(parse![:slice]).to eq 3.months
        end
      end

      context 'with --slice in years' do
        let(:argv) { %W[--slice 3y --month 2023-1-1 --issuer #{issuer}] }

        it 'slice is 3 years' do
          expect(parse![:slice]).to eq 3.years
        end
      end
    end

    context 'with --threads' do
      context 'if threads is a string of a num between 1 and 30' do
        let(:argv) { %W[--date 2023-1-1 --issuer #{issuer} --threads 9 ] }

        it 'thread is that number' do
          expect(parse![:threads]).to eq 9
        end
      end

      context 'if threads is a random string' do
        let(:argv) { %W[--date 2023-1-1 --issuer #{issuer} --threads abcd ] }

        it 'thread is the default of 5' do
          expect { parse! }.to raise_error(
            StandardError, 'Number of threads must be between 1 and 30 inclusive'
          )
        end
      end

      context 'if threads is below 0' do
        let(:argv) { %W[--date 2023-1-1 --issuer #{issuer} --threads -3 ] }

        it 'throws an error' do
          expect { parse! }.to raise_error(
            StandardError, 'Number of threads must be between 1 and 30 inclusive'
          )
        end
      end

      context 'if threads is above 31' do
        let(:argv) { %W[--date 2023-1-1 --issuer #{issuer} --threads 31 ] }

        it 'throws an error' do
          expect { parse! }.to raise_error(
            StandardError, 'Number of threads must be between 1 and 30 inclusive'
          )
        end
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
