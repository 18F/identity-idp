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
        # Online verification user (failed each vendor once, then succeeded once)
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth welcome submitted' },
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth image upload vendor submitted', 'doc_auth_failed_non_fraud' => '1' },
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth image upload vendor submitted', 'success' => '1' },
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth verify proofing results', 'success' => '0' },
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth verify proofing results', 'success' => '1' },
        { 'user_id' => 'user1', 'name' => 'IdV: phone confirmation vendor', 'success' => '0' },
        { 'user_id' => 'user1', 'name' => 'IdV: phone confirmation vendor', 'success' => '1' },
        { 'user_id' => 'user1', 'name' => 'IdV: final resolution', 'identity_verified' => '1' },

        # Letter requested user (incomplete)
        { 'user_id' => 'user2', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user2', 'name' => 'IdV: doc auth welcome submitted' },
        { 'user_id' => 'user2', 'name' => 'IdV: doc auth image upload vendor submitted', 'success' => '1' },
        { 'user_id' => 'user2', 'name' => 'IdV: final resolution', 'gpo_verification_pending' => '1' },

        # Fraud review user (incomplete)
        { 'user_id' => 'user3', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user3', 'name' => 'IdV: doc auth welcome submitted' },
        { 'user_id' => 'user3', 'name' => 'IdV: doc auth image upload vendor submitted', 'success' => '1' },
        { 'user_id' => 'user3', 'name' => 'IdV: final resolution', 'fraud_review_pending' => '1' },
        { 'user_id' => 'user3', 'name' => 'Fraud: Profile review passed', 'success' => '1' },

        # Fraud review user (rejected)
        { 'user_id' => 'user3', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user3', 'name' => 'IdV: doc auth welcome submitted' },
        { 'user_id' => 'user3', 'name' => 'IdV: doc auth image upload vendor submitted', 'success' => '1' },
        { 'user_id' => 'user3', 'name' => 'IdV: final resolution', 'fraud_review_pending' => '1' },
        { 'user_id' => 'user3', 'name' => 'Fraud: Profile review rejected', 'success' => '1' },

        # Success through address confirmation user
        { 'user_id' => 'user4', 'name' => 'IdV: GPO verification submitted' },
        { 'user_id' => 'user4', 'name' => 'Fraud: Profile review passed', 'success' => '1' },

        # Success through in-person verification, failed doc auth (rejected)
        { 'user_id' => 'user5', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user5', 'name' => 'IdV: doc auth welcome submitted' },
        { 'user_id' => 'user5', 'name' => 'IdV: doc auth image upload vendor submitted', 'doc_auth_failed_non_fraud' => '1' },
        { 'user_id' => 'user5', 'name' => 'IdV: final resolution', 'in_person_verification_pending' => '1' },
        { 'user_id' => 'user5', 'name' => 'GetUspsProofingResultsJob: Enrollment status updated' },

        # Incomplete user
        { 'user_id' => 'user6', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user6', 'name' => 'IdV: doc auth welcome submitted' },
        { 'user_id' => 'user6', 'name' => 'IdV: doc auth image upload vendor submitted', 'doc_auth_failed_non_fraud' => '1' },
      ],
    )

    allow(report).to receive(:cloudwatch_client).and_return(cloudwatch_client)
  end

  describe '#as_csv' do
    it 'renders a csv report' do
      expected_csv = [
        ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"],
        ['Report Generated', Date.today.to_s], # rubocop:disable Rails/Date
        ['Issuer', issuer],
        [],
        ['Metric', '# of Users'],
        [],
        ['IDV started', 5],
        ['Welcome Submitted', 5],
        ['Image Submitted', 5],
        [],
        ['Workflow completed', 4],
        ['Workflow completed - With Phone Number', 1],
        ['Workflow completed - With Phone Number - Fraud Review', 1],
        ['Workflow completed - GPO Pending', 1],
        ['Workflow completed - GPO Pending - Fraud Review', 0],
        ['Workflow completed - In-Person Pending', 1],
        ['Workflow completed - In-Person Pending - Fraud Review', 0],
        ['Workflow completed - GPO + In-Person Pending', 0],
        ['Workflow completed - GPO + In-Person Pending - Fraud Review', 0],
        [],
        ['Fraud review rejected', 1],
        ['Successfully Verified', 4],
        ['Successfully Verified - With phone number', 1],
        ['Successfully Verified - With mailed code', 1],
        ['Successfully Verified - In Person', 1],
        ['Successfully Verified - Passed fraud review', 2],
        ['Blanket Proofing Rate (IDV Started to Successfully Verified)', 0.8],
        ['Intent Proofing Rate (Welcome Submitted to Successfully Verified)', 0.8],
        ['Actual Proofing Rate (Image Submitted to Successfully Verified)', 0.8],
        ['Industry Proofing Rate (Verified minus IDV Rejected)', 0.8],
      ]
      # rubocop:enable Layout/LineLength

      aggregate_failures do
        report.as_csv.zip(expected_csv).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
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
        [],
        ['IDV started', '5'],
        ['Welcome Submitted', '5'],
        ['Image Submitted', '5'],
        [],
        ['Workflow completed', '4'],
        ['Workflow completed - With Phone Number', '1'],
        ['Workflow completed - With Phone Number - Fraud Review', '1'],
        ['Workflow completed - GPO Pending', '1'],
        ['Workflow completed - GPO Pending - Fraud Review', '0'],
        ['Workflow completed - In-Person Pending', '1'],
        ['Workflow completed - In-Person Pending - Fraud Review', '0'],
        ['Workflow completed - GPO + In-Person Pending', '0'],
        ['Workflow completed - GPO + In-Person Pending - Fraud Review', '0'],
        [],
        ['Fraud review rejected', '1'],
        ['Successfully Verified', '4'],
        ['Successfully Verified - With phone number', '1'],
        ['Successfully Verified - With mailed code', '1'],
        ['Successfully Verified - In Person', '1'],
        ['Successfully Verified - Passed fraud review', '2'],
        ['Blanket Proofing Rate (IDV Started to Successfully Verified)', '0.8'],
        ['Intent Proofing Rate (Welcome Submitted to Successfully Verified)', '0.8'],
        ['Actual Proofing Rate (Image Submitted to Successfully Verified)', '0.8'],
        ['Industry Proofing Rate (Verified minus IDV Rejected)', '0.8'],
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
      expect(report.data.transform_values(&:count)).to eq(
        # events
        'GetUspsProofingResultsJob: Enrollment status updated' => 1,
        'IdV: doc auth image upload vendor submitted' => 5,
        'IdV: doc auth verify proofing results' => 1,
        'IdV: doc auth welcome submitted' => 5,
        'IdV: doc auth welcome visited' => 5,
        'IdV: final resolution' => 4,
        'IdV: GPO verification submitted' => 1,
        'IdV: phone confirmation vendor' => 1,

        # results
        'IdV: final resolution - Fraud Review Pending' => 1,
        'IdV: final resolution - GPO Pending' => 1,
        'IdV: final resolution - In Person Proofing' => 1,
        'IdV: final resolution - Verified' => 1,
        'IdV Reject: Doc Auth' => 3,
        'IdV Reject: Phone Finder' => 1,
        'IdV Reject: Verify' => 1,
        'Fraud: Profile review passed' => 2,
        'Fraud: Profile review rejected' => 1,
      )
    end
  end

  describe '#idv_doc_auth_rejected' do
    it 'is the number of users who failed proofing and never passed' do
      expect(report.idv_doc_auth_rejected).to eq(1)
    end
  end

  describe '#merge', :freeze_time do
    it 'makes a new instance with merged data' do
      report1 = Reporting::IdentityVerificationReport.new(
        time_range: 4.days.ago..3.days.ago,
        issuers: %w[a],
      )
      allow(report1).to receive(:data).and_return(
        'IdV: doc auth image upload vendor submitted' => %w[a b].to_set,
        'IdV: final resolution' => %w[a].to_set,
      )

      report2 = Reporting::IdentityVerificationReport.new(
        time_range: 2.days.ago..1.day.ago,
        issuers: %w[b],
      )
      allow(report2).to receive(:data).and_return(
        'IdV: doc auth image upload vendor submitted' => %w[b c].to_set,
        'IdV: final resolution' => %w[c].to_set,
      )

      merged = report1.merge(report2)

      aggregate_failures do
        expect(merged.time_range).to eq(4.days.ago..1.day.ago)

        expect(merged.issuers).to eq(%w[a b])

        expect(merged.data).to eq(
          'IdV: doc auth image upload vendor submitted' => %w[a b c].to_set,
          'IdV: final resolution' => %w[a c].to_set,
        )
      end
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

    it 'includes GPO submission events with old name' do
      expected = <<~FRAGMENT
        | filter (name in ["IdV: enter verify by mail code submitted","IdV: GPO verification submitted"] and properties.event_properties.success = 1 and !properties.event_properties.pending_in_person_enrollment and !properties.event_properties.fraud_check_failed)
                 or (name not in ["IdV: enter verify by mail code submitted","IdV: GPO verification submitted"])
      FRAGMENT

      expect(subject.query).to include(expected)
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
