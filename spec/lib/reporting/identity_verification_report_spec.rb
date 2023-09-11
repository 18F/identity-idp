require 'rails_helper'
require 'reporting/identity_verification_report'

RSpec.describe Reporting::IdentityVerificationReport do
  let(:issuer) { 'my:example:issuer' }
  let(:time_range) { Date.new(2022, 1, 1).all_day }

  subject(:report) do
    Reporting::IdentityVerificationReport.new(issuers: Array(issuer), time_range:)
  end

  # rubocop:disable Layout/LineLength
  before do
    cloudwatch_client = double(
      'Reporting::CloudwatchClient',
      fetch: [
        # Online verification user
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth welcome submitted' },
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth image upload vendor submitted' },
        { 'user_id' => 'user1', 'name' => 'IdV: final resolution', 'identity_verified' => '1' },

        # Letter requested user (incomplete)
        { 'user_id' => 'user2', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user2', 'name' => 'IdV: doc auth welcome submitted' },
        { 'user_id' => 'user2', 'name' => 'IdV: doc auth image upload vendor submitted' },
        { 'user_id' => 'user2', 'name' => 'IdV: final resolution', 'gpo_verification_pending' => '1' },

        # Fraud review user (incomplete)
        { 'user_id' => 'user3', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user3', 'name' => 'IdV: doc auth welcome submitted' },
        { 'user_id' => 'user3', 'name' => 'IdV: doc auth image upload vendor submitted' },
        { 'user_id' => 'user3', 'name' => 'IdV: final resolution', 'fraud_review_pending' => '1' },

        # Success through address confirmation user
        { 'user_id' => 'user4', 'name' => 'IdV: GPO verification submitted' },

        # Success through in-person verification
        { 'user_id' => 'user5', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user5', 'name' => 'IdV: doc auth welcome submitted' },
        { 'user_id' => 'user5', 'name' => 'IdV: doc auth image upload vendor submitted' },
        { 'user_id' => 'user5', 'name' => 'IdV: final resolution', 'in_person_verification_pending' => '1' },
        { 'user_id' => 'user5', 'name' => 'GetUspsProofingResultsJob: Enrollment status updated' },

        # Incomplete user
        { 'user_id' => 'user6', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user6', 'name' => 'IdV: doc auth welcome submitted' },
        { 'user_id' => 'user6', 'name' => 'IdV: doc auth image upload vendor submitted' },
      ],
    )

    allow(report).to receive(:cloudwatch_client).and_return(cloudwatch_client)
  end
  # rubocop:enable Layout/LineLength

  describe '#to_csv' do
    it 'generates a csv' do
      csv = CSV.parse(report.to_csv, headers: false)

      expected_csv = [
        ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"],
        ['Report Generated', Date.today.to_s], # rubocop:disable Rails/Date
        ['Issuer', issuer],
        [],
        ['Metric', '# of Users'],
        [],
        ['Started IdV Verification', '5'],
        ['Submitted welcome page', '5'],
        ['Images uploaded', '5'],
        [],
        ['Workflow completed', '4'],
        ['Workflow completed - Verified', '1'],
        ['Workflow completed - Total Pending', '3'],
        ['Workflow completed - GPO Pending', '1'],
        ['Workflow completed - In-Person Pending', '1'],
        ['Workflow completed - Fraud Review Pending', '1'],
        [],
        ['Successfully verified', '3'],
        ['Successfully verified - Inline', '1'],
        ['Successfully verified - GPO Code Entry', '1'],
        ['Successfully verified - In Person', '1'],
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
        'IdV: doc auth image upload vendor submitted' => 5,
        'IdV: doc auth welcome submitted' => 5,
        'IdV: doc auth welcome visited' => 5,
        'IdV: final resolution' => 4,
        'IdV: final resolution - GPO Pending' => 1,
        'IdV: final resolution - In Person Proofing' => 1,
        'IdV: final resolution - Fraud Review Pending' => 1,
        'IdV: final resolution - Verified' => 1,
        'IdV: GPO verification submitted' => 1,
        'GetUspsProofingResultsJob: Enrollment status updated' => 1,
      )
    end
  end

  describe '#query' do
    context 'with an issuer' do
      it 'includes an issuer filter' do
        result = subject.query

        expect(result).to include('| filter properties.service_provider IN ["my:example:issuer"]')
      end
    end

    context 'without an issuer' do
      let(:issuer) { nil }

      it 'does not include an issuer filter' do
        result = subject.query

        expect(result).to_not include('filter properties.service_provider')
      end
    end
  end

  describe '#cloudwatch_client' do
    let(:opts) { {} }
    let(:subject) { described_class.new(issuers: Array(issuer), time_range:, **opts) }
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
