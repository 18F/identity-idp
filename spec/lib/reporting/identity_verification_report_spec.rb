require 'rails_helper'
require 'reporting/identity_verification_report'

RSpec.describe Reporting::IdentityVerificationReport do
  let(:issuer) { nil }
  let(:time_range) { Date.new(2022, 1, 1).all_day }

  let(:cloudwatch_logs) do
    [
      # Online verification user (failed each vendor once, then succeeded once)
      { 'user_id' => 'user1', 'name' => 'IdV: doc auth welcome visited' },
      { 'user_id' => 'user1', 'name' => 'IdV: doc auth welcome submitted' },
      { 'user_id' => 'user1',
        'name' => 'IdV: doc auth image upload vendor submitted',
        'doc_auth_failed_non_fraud' => '1' },
      { 'user_id' => 'user1',
        'name' => 'IdV: doc auth image upload vendor submitted',
        'success' => '1' },
      { 'user_id' => 'user1', 'name' => 'IdV: doc auth verify proofing results', 'success' => '0' },
      { 'user_id' => 'user1', 'name' => 'IdV: doc auth verify proofing results', 'success' => '1' },
      { 'user_id' => 'user1', 'name' => 'IdV: phone confirmation vendor', 'success' => '0' },
      { 'user_id' => 'user1', 'name' => 'IdV: phone confirmation vendor', 'success' => '1' },
      { 'user_id' => 'user1', 'name' => 'IdV: final resolution', 'profile_not_pending' => '1' },

      # Letter requested user (incomplete)
      { 'user_id' => 'user2', 'name' => 'IdV: doc auth welcome visited' },
      { 'user_id' => 'user2', 'name' => 'IdV: doc auth welcome submitted' },
      { 'user_id' => 'user2',
        'name' => 'idv_socure_verification_data_requested',
        'success' => '1' },
      { 'user_id' => 'user2',
        'name' => 'IdV: final resolution',
        'gpo_verification_pending' => '1' },

      # Fraud review passed user
      { 'user_id' => 'user3', 'name' => 'IdV: doc auth welcome visited' },
      { 'user_id' => 'user3', 'name' => 'IdV: doc auth welcome submitted' },
      { 'user_id' => 'user3',
        'name' => 'IdV: doc auth image upload vendor submitted',
        'success' => '1' },
      { 'user_id' => 'user3', 'name' => 'IdV: final resolution', 'fraud_review_pending' => '1' },
      { 'user_id' => 'user3', 'name' => 'Fraud: Profile review passed', 'success' => '1' },

      # GPO confirmation followed by passing fraud review
      { 'user_id' => 'user4', 'name' => 'IdV: GPO verification submitted' },
      { 'user_id' => 'user4', 'name' => 'Fraud: Profile review passed', 'success' => '1' },

      # Success through in-person verification, failed doc auth (rejected)
      { 'user_id' => 'user5', 'name' => 'IdV: doc auth welcome visited' },
      { 'user_id' => 'user5', 'name' => 'IdV: doc auth welcome submitted' },
      { 'user_id' => 'user5',
        'name' => 'IdV: doc auth image upload vendor submitted',
        'doc_auth_failed_non_fraud' => '1' },
      { 'user_id' => 'user5',
        'name' => 'IdV: final resolution',
        'in_person_verification_pending' => '1' },
      { 'user_id' => 'user5', 'name' => 'GetUspsProofingResultsJob: Enrollment status updated' },

      # Incomplete user
      { 'user_id' => 'user6', 'name' => 'IdV: doc auth welcome visited' },
      { 'user_id' => 'user6', 'name' => 'IdV: doc auth welcome submitted' },
      { 'user_id' => 'user6',
        'name' => 'IdV: doc auth image upload vendor submitted',
        'doc_auth_failed_non_fraud' => '1' },

      # Fraud review user (rejected)
      { 'user_id' => 'user7', 'name' => 'IdV: doc auth welcome visited' },
      { 'user_id' => 'user7', 'name' => 'IdV: doc auth welcome submitted' },
      { 'user_id' => 'user7',
        'name' => 'IdV: doc auth image upload vendor submitted',
        'success' => '1' },
      { 'user_id' => 'user7', 'name' => 'IdV: final resolution', 'fraud_review_pending' => '1' },
      { 'user_id' => 'user7', 'name' => 'Fraud: Profile review rejected', 'success' => '1' },

      # Just fraud rejection
      { 'user_id' => 'user8', 'name' => 'Fraud: Profile review rejected', 'success' => '1' },

      # GPO confirmation followed by fraud rejection
      { 'user_id' => 'user9',
        'name' => 'IdV: GPO verification submitted',
        'fraud_review_pending' => '1' },
      { 'user_id' => 'user9', 'name' => 'Fraud: Profile review rejected', 'success' => '1' },

      # IPP user in fraud review queue who is then passed
      {
        'user_id' => 'user10',
        'name' => 'GetUspsProofingResultsJob: Enrollment status updated',
        'fraud_review_pending' => '1',
      },
      { 'user_id' => 'user10', 'name' => 'Fraud: Profile review passed', 'success' => '1' },

      # User who bounced on welcome screen
      { 'user_id' => 'user11', 'name' => 'IdV: doc auth welcome visited' },
    ]
  end

  subject(:report) do
    Reporting::IdentityVerificationReport.new(issuers: Array(issuer), time_range:)
  end

  before do
    stub_cloudwatch_logs(cloudwatch_logs)
  end

  describe '#as_csv' do
    it 'renders a csv report' do
      expected_csv = [
        ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"],
        ['Report Generated', Date.today.to_s], # rubocop:disable Rails/Date
        issuer && ['Issuer', issuer],
        [],
        ['Metric', '# of Users'],
        [],
        ['IDV started', 7],
        ['Welcome Submitted', 6],
        ['Image Submitted', 5],
        ['Socure Verification Data Requested', 1],
        [],
        ['Workflow completed', 5],
        ['Workflow completed - With Phone Number', 1],
        ['Workflow completed - With Phone Number - Fraud Review', 2],
        ['Workflow completed - GPO Pending', 1],
        ['Workflow completed - GPO Pending - Fraud Review', 0],
        ['Workflow completed - In-Person Pending', 1],
        ['Workflow completed - In-Person Pending - Fraud Review', 0],
        ['Workflow completed - GPO + In-Person Pending', 0],
        ['Workflow completed - GPO + In-Person Pending - Fraud Review', 0],
        [],
        ['Fraud review rejected', 3],
        ['Successfully Verified', 5],
        ['Successfully Verified - With phone number', 1],
        ['Successfully Verified - With mailed code', 1],
        ['Successfully Verified - In Person', 1],
        ['Successfully Verified - Passed fraud review', 3],
        ['Blanket Proofing Rate (IDV Started to Successfully Verified)', (5.0 / 7.0)],
        ['Intent Proofing Rate (Welcome Submitted to Successfully Verified)', (5.0 / 6.0)],
        ['Actual Proofing Rate (Image Submitted to Successfully Verified)', (5.0 / 6.0)],
        ['Industry Proofing Rate (Verified minus IDV Rejected)', (5.0 / 6.0)],
      ].compact
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
        issuer && ['Issuer', issuer],
        [],
        ['Metric', '# of Users'],
        [],
        ['IDV started', '7'],
        ['Welcome Submitted', '6'],
        ['Image Submitted', '5'],
        ['Socure Verification Data Requested', '1'],
        [],
        ['Workflow completed', '5'],
        ['Workflow completed - With Phone Number', '1'],
        ['Workflow completed - With Phone Number - Fraud Review', '2'],
        ['Workflow completed - GPO Pending', '1'],
        ['Workflow completed - GPO Pending - Fraud Review', '0'],
        ['Workflow completed - In-Person Pending', '1'],
        ['Workflow completed - In-Person Pending - Fraud Review', '0'],
        ['Workflow completed - GPO + In-Person Pending', '0'],
        ['Workflow completed - GPO + In-Person Pending - Fraud Review', '0'],
        [],
        ['Fraud review rejected', '3'],
        ['Successfully Verified', '5'],
        ['Successfully Verified - With phone number', '1'],
        ['Successfully Verified - With mailed code', '1'],
        ['Successfully Verified - In Person', '1'],
        ['Successfully Verified - Passed fraud review', '3'],
        ['Blanket Proofing Rate (IDV Started to Successfully Verified)', (5.0 / 7.0).to_s],
        ['Intent Proofing Rate (Welcome Submitted to Successfully Verified)', (5.0 / 6.0).to_s],
        ['Actual Proofing Rate (Image Submitted to Successfully Verified)', (5.0 / 6.0).to_s],
        ['Industry Proofing Rate (Verified minus IDV Rejected)', (5.0 / 6.0).to_s],
      ].compact

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
        'idv_socure_verification_data_requested' => 1,
        'IdV: doc auth verify proofing results' => 1,
        'IdV: doc auth welcome submitted' => 6,
        'IdV: doc auth welcome visited' => 7,
        'IdV: final resolution' => 5,
        'IdV: GPO verification submitted' => 1,
        'IdV: phone confirmation vendor' => 1,

        # results
        'IdV: final resolution - Fraud Review Pending' => 2,
        'IdV: final resolution - GPO Pending' => 1,
        'IdV: final resolution - In Person Proofing' => 1,
        'IdV: final resolution - Verified' => 1,
        'IdV Reject: Doc Auth' => 3,
        'IdV Reject: Phone Finder' => 1,
        'IdV Reject: Verify' => 1,
        'Fraud: Profile review passed' => 3,
        'Fraud: Profile review rejected' => 3,
      )
    end

    context 'when an issuer is specified' do
      let(:issuer) { 'my:example:issuer' }

      context 'and events have service provider data' do
        let(:cloudwatch_logs) do
          super().map do |event|
            event.merge(
              'service_provider' => issuer,
            )
          end
        end

        it 'includes users per sp' do
          expect(report.data.transform_values(&:count)).to include(
            'sp:my:example:issuer' => 11,
          )
        end
      end
    end
  end

  describe '#idv_doc_auth_rejected' do
    it 'is the number of users who failed proofing and never passed' do
      expect(report.idv_doc_auth_rejected).to eq(1)
    end
  end

  describe '#fraud_review_passed' do
    let(:service_provider_for_non_fraud_events) { nil }
    let(:service_provider_for_fraud_events) { nil }

    let(:cloudwatch_logs) do
      super().map do |event|
        is_fraud_event = event['name'].include?('Fraud')
        event.merge(
          'service_provider' => is_fraud_event ?
            service_provider_for_fraud_events :
            service_provider_for_non_fraud_events,
        )
      end
    end

    context 'when an issuer is specified' do
      let(:issuer) { 'my:example:issuer' }

      context 'and fraud events are not tagged with sp information' do
        context 'but other events are tagged for the sp' do
          let(:service_provider_for_non_fraud_events) { issuer }
          it 'is users who completed workflow + passed fraud review and any event matches issuer' do
            expect(report.fraud_review_passed).to eql(3)
          end
        end

        context 'and other events are not tagged with an sp' do
          it 'does not include any users' do
            expect(report.fraud_review_passed).to eql(0)
          end
        end

        context 'and other events are tagged for a different sp' do
          let(:service_provider_for_non_fraud_events) { 'some:other:sp' }

          it 'does not include any users' do
            expect(report.fraud_review_passed).to eql(0)
          end
        end
      end
      context 'and fraud events are tagged with sp information' do
        let(:service_provider_for_fraud_events) { issuer }

        context 'but other events are not tagged at all' do
          it 'counts all fraud events tagged for the sp' do
            expect(report.fraud_review_passed).to eql(3)
          end
        end

        context 'but other events are not tagged with the same SP' do
          let(:service_provider_for_non_fraud_events) { 'some:other:sp' }
          it 'still counts all fraud events tagged for the sp' do
            expect(report.fraud_review_passed).to eql(3)
          end
        end

        context 'but the fraud events are tagged for the wrong sp' do
          let(:service_provider_for_fraud_events) { 'some:other:sp' }

          context 'and other events are not tagged' do
            it 'does not find any users' do
              expect(report.fraud_review_passed).to eql(0)
            end
          end

          context 'and other events are tagged for the right sp' do
            let(:service_provider_for_non_fraud_events) { issuer }
            it 'still finds those users' do
              expect(report.fraud_review_passed).to eql(3)
            end
          end
        end
      end
    end

    context 'when an issuer is not specified' do
      let(:issuer) { nil }

      it 'includes users who did not complete workflow and passed fraud review' do
        expect(report.fraud_review_passed).to eql(3)
      end
    end
  end

  describe '#idv_fraud_rejected' do
    let(:service_provider_for_non_fraud_events) { nil }
    let(:service_provider_for_fraud_events) { nil }

    let(:cloudwatch_logs) do
      super().map do |event|
        is_fraud_event = event['name'].include?('Fraud')
        event.merge(
          'service_provider' => is_fraud_event ?
            service_provider_for_fraud_events :
            service_provider_for_non_fraud_events,
        )
      end
    end

    context 'when an issuer is specified' do
      let(:issuer) { 'my:example:issuer' }

      context 'and fraud events are not tagged with sp information' do
        context 'but other events are tagged for the sp' do
          let(:service_provider_for_non_fraud_events) { issuer }
          it 'is the count of fraud rejected users where any other event matches on issuer' do
            expect(report.idv_fraud_rejected).to eql(2)
          end
        end

        context 'and other events are not tagged with an sp' do
          it 'does not include any users' do
            expect(report.idv_fraud_rejected).to eql(0)
          end
        end

        context 'and other events are tagged for a different sp' do
          let(:service_provider_for_non_fraud_events) { 'some:other:sp' }

          it 'does not include any users' do
            expect(report.idv_fraud_rejected).to eql(0)
          end
        end
      end

      context 'and fraud events are tagged with sp information' do
        let(:service_provider_for_fraud_events) { issuer }

        context 'but other events are not tagged at all' do
          it 'counts all fraud events tagged for the sp' do
            expect(report.idv_fraud_rejected).to eql(3)
          end
        end

        context 'but other events are not tagged with the same SP' do
          let(:service_provider_for_non_fraud_events) { 'some:other:sp' }
          it 'still counts all fraud events tagged for the sp' do
            expect(report.idv_fraud_rejected).to eql(3)
          end
        end

        context 'but the fraud events are tagged for the wrong sp' do
          let(:service_provider_for_fraud_events) { 'some:other:sp' }

          context 'and other events are not tagged' do
            it 'does not find any users' do
              expect(report.idv_fraud_rejected).to eql(0)
            end
          end

          context 'and other events are tagged for the right sp' do
            let(:service_provider_for_non_fraud_events) { issuer }
            it 'still finds those users' do
              expect(report.idv_fraud_rejected).to eql(2)
            end
          end
        end
      end
    end

    context 'when an issuer is not specified' do
      let(:issuer) { nil }

      it 'includes users who did not complete workflow and failed fraud review' do
        expect(report.idv_fraud_rejected).to eql(3)
      end
    end
  end

  describe '#successfully_verified_users' do
    it 'is the count of users who verified or passed fraud review' do
      expect(report.successfully_verified_users).to eql(5)
    end

    context 'multiple issuers specified' do
      let(:cloudwatch_logs) do
        [
          { 'user_id' => 'user1',
            'name' => 'IdV: final resolution',
            'profile_not_pending' => '1',
            'service_provider' => 'issuer1' },
          { 'user_id' => 'user2',
            'name' => 'IdV: final resolution',
            'profile_not_pending' => '1',
            'service_provider' => 'issuer2' },
          { 'user_id' => 'user4',
            'name' => 'IdV: final resolution',
            'fraud_review_pending' => '1',
            'service_provider' => 'issuer1' },
          { 'user_id' => 'user4', 'name' => 'Fraud: Profile review passed', 'success' => '1' },
          { 'user_id' => 'user5',
            'name' => 'IdV: final resolution',
            'fraud_review_pending' => '1',
            'service_provider' => 'issuer2' },
          { 'user_id' => 'user5', 'name' => 'Fraud: Profile review rejected', 'success' => '1' },
        ]
      end

      it 'combines fraud results across issuers' do
        expect(report.successfully_verified_users).to eql(3)
      end
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
      let(:issuer) { 'my:example:issuer' }

      it 'includes an issuer filter' do
        result = subject.query

        expect(result).to include('| filter service_provider IN ["my:example:issuer"]')
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
        | filter (name in ["IdV: enter verify by mail code submitted","IdV: GPO verification submitted"] and properties.event_properties.success = 1 and !properties.event_properties.pending_in_person_enrollment)
                 or (name not in ["IdV: enter verify by mail code submitted","IdV: GPO verification submitted"])
      FRAGMENT

      expect(subject.query).to include(expected)
    end

    it 'normalizes different attributes into fraud_review_pending' do
      # rubocop:disable Layout/LineLength
      elements = [
        'coalesce(properties.event_properties.fraud_review_pending, 0)',
        '!isblank(properties.event_properties.fraud_pending_reason)',
        'coalesce(properties.event_properties.fraud_check_failed, 0)',
        'coalesce((ispresent(properties.event_properties.tmx_status) and properties.event_properties.tmx_status in ["threatmetrix_review", "threatmetrix_reject"]), 0)',
      ]
      # rubocop:enable Layout/LineLength

      expected = <<~FRAGMENT
        (#{elements.join(" OR ")}) AS fraud_review_pending
      FRAGMENT
      expect(subject.query).to include(expected)
    end

    it 'includes IPP events without regard to tmx_status' do
      expected = <<~FRAGMENT
        | filter (name = "GetUspsProofingResultsJob: Enrollment status updated" and properties.event_properties.passed = 1)
                 or (name != "GetUspsProofingResultsJob: Enrollment status updated")
      FRAGMENT
      expect(subject.query).to include(expected)
    end

    it 'accepts properties.event_properties.issuer as service_provider' do
      expected = <<~FRAGMENT
        coalesce(properties.service_provider, properties.event_properties.issuer) AS service_provider
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

    describe '#verified_user_count' do
      let!(:profile) do
        create(
          :profile,
          :active,
          created_at: time_range.end.end_of_day,
          verified_at: time_range.end.end_of_day,
        )
      end
      it 'counts users through end of day' do
        expect(report.verified_user_count).to eq(1)
      end
    end
  end
end
