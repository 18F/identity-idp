require 'rails_helper'
require 'reporting/identity_verification_report'

RSpec.describe Reporting::IdentityVerificationReport do
  let(:issuer) { 'my:example:issuer' }
  let(:time_range) { Date.new(2022, 1, 1).all_day }

  subject(:report) { Reporting::IdentityVerificationReport.new(issuer:, time_range:) }

  before do
    cloudwatch_client = double(
      'Reporting::CloudwatchClient',
      fetch: [
        # Online verification user
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth image upload vendor submitted' },
        { 'user_id' => 'user1', 'name' => 'IdV: final resolution' },

        # Letter requested user (incomplete)
        { 'user_id' => 'user2', 'name' => 'IdV: doc auth image upload vendor submitted' },
        { 'user_id' => 'user2', 'name' => 'IdV: USPS address letter requested' },

        # Success through address confirmation user
        { 'user_id' => 'user3', 'name' => 'IdV: GPO verification submitted' },

        # Success through in-person verification
        { 'user_id' => 'user4', 'name' => 'IdV: doc auth image upload vendor submitted' },
        { 'user_id' => 'user4', 'name' => 'USPS IPPaaS enrollment created' },
        { 'user_id' => 'user4', 'name' => 'GetUspsProofingResultsJob: Enrollment status updated' },

        # Incomplete user
        { 'user_id' => 'user5', 'name' => 'IdV: doc auth image upload vendor submitted' },
      ],
    )

    allow(report).to receive(:cloudwatch_client).and_return(cloudwatch_client)
  end

  describe '#to_csv' do
    it 'generates a csv' do
      csv = CSV.parse(report.to_csv, headers: false)

      expected_csv = [
        ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"],
        ['Report Generated', Date.today.to_s], # rubocop:disable Rails/Date
        ['Issuer', issuer],
        [],
        ['Metric', '# of Users'],
        ['Started IdV Verification', '4'],
        ['Incomplete Users', '1'],
        ['Address Confirmation Letters Requested', '1'],
        ['Started In-Person Verification', '1'],
        ['Alternative Process Users', '0'],
        ['Success through Online Verification', '1'],
        ['Success through Address Confirmation Letters', '1'],
        ['Success through In-Person Verification', '1'],
        ['Successfully Verified Users', '3'],
      ]

      aggregate_failures do
        csv.map(&:to_a).zip(expected_csv).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
  end

  describe '#data' do
    it 'counts unique users per event as a hash' do
      expect(report.data).to eq(
        'GetUspsProofingResultsJob: Enrollment status updated' => 1,
        'IdV: doc auth image upload vendor submitted' => 4,
        'IdV: final resolution' => 1,
        'IdV: GPO verification submitted' => 1,
        'IdV: USPS address letter requested' => 1,
        'USPS IPPaaS enrollment created' => 1,
      )
    end
  end

  describe '#cloudwatch_client' do
    let(:opts) { {} }
    let(:subject) { described_class.new(issuer:, time_range:, **opts) }
    let(:default_args) do
      {
        num_threads: 5,
        ensure_complete_logs: true,
        slice_interval: 3.hours,
        progress: false,
        logger: nil,
      }
    end

    describe 'when all args are default' do
      it 'creates a client with the default options' do
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end

    describe 'when verbose is passed in' do
      let(:opts) { { verbose: true } }
      let(:logger) { double Logger }

      before do
        expect(Logger).to receive(:new).with(STDERR).and_return logger
        default_args[:logger] = logger
      end

      it 'creates a client with the expected logger' do
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end

    describe 'when progress is passed in as true' do
      let(:opts) { { progress: true } }
      before { default_args[:progress] = true }

      it 'creates a client with progress as true' do
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end

    describe 'when threads is passed in' do
      let(:opts) { { threads: 17 } }
      before { default_args[:num_threads] = 17 }

      it 'creates a client with the expected thread count' do
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end

    describe 'when slice is passed in' do
      let(:opts) { { slice: 2.weeks } }
      before { default_args[:slice_interval] = 2.weeks }

      it 'creates a client with expected time slice' do
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end
  end
end
