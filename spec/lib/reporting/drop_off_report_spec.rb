require 'rails_helper'
require 'reporting/drop_off_report'

RSpec.describe Reporting::DropOffReport do
  let(:issuer) { 'my:example:issuer' }
  let(:time_range) { Date.new(2022, 1, 1).all_day }

  subject(:report) { Reporting::DropOffReport.new(issuers: [issuer], time_range:) }

  before do
    stub_multiple_cloudwatch_logs(
      [
        # finishes funnel
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth welcome submitted' },
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth image upload vendor submitted' },
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth document_capture visited' },
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth ssn visited' },
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth verify visited' },
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth verify submitted' },
        { 'user_id' => 'user1', 'name' => 'IdV: phone of record visited' },
        { 'user_id' => 'user1', 'name' => 'idv_enter_password_visited' },
        { 'user_id' => 'user1', 'name' => 'idv_enter_password_submitted' },
        { 'user_id' => 'user1', 'name' => 'IdV: personal key submitted' },
        { 'user_id' => 'user1', 'identity_verified' => '1', 'name' => 'IdV: final resolution' },

        # gets through phone finder, then drops
        { 'user_id' => 'user2', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user2', 'name' => 'IdV: doc auth welcome submitted' },
        { 'user_id' => 'user2', 'name' => 'IdV: doc auth image upload vendor submitted' },
        { 'user_id' => 'user2', 'name' => 'IdV: doc auth document_capture visited' },
        { 'user_id' => 'user2', 'name' => 'IdV: doc auth ssn visited' },
        { 'user_id' => 'user2', 'name' => 'IdV: doc auth verify visited' },
        { 'user_id' => 'user2', 'name' => 'IdV: doc auth verify submitted' },
        { 'user_id' => 'user2', 'name' => 'IdV: phone of record visited' },

        # gets to SSN view, then drops
        { 'user_id' => 'user3', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user3', 'name' => 'IdV: doc auth welcome submitted' },
        { 'user_id' => 'user3', 'name' => 'IdV: doc auth image upload vendor submitted' },
        { 'user_id' => 'user3', 'name' => 'IdV: doc auth document_capture visited' },
        { 'user_id' => 'user3', 'name' => 'IdV: doc auth ssn visited' },

        # uploads a document, then drops
        { 'user_id' => 'user4', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user4', 'name' => 'IdV: doc auth welcome submitted' },
        { 'user_id' => 'user4', 'name' => 'IdV: doc auth image upload vendor submitted' },
        { 'user_id' => 'user4', 'name' => 'IdV: doc auth document_capture visited' },

        # bails after viewing the user agreement
        { 'user_id' => 'user5', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user5', 'name' => 'IdV: doc auth welcome submitted' },

        # finishes funnel but has to wait for GPO letter
        { 'user_id' => 'user6', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user6', 'name' => 'IdV: doc auth welcome submitted' },
        { 'user_id' => 'user6', 'name' => 'IdV: doc auth image upload vendor submitted' },
        { 'user_id' => 'user6', 'name' => 'IdV: doc auth document_capture visited' },
        { 'user_id' => 'user6', 'name' => 'IdV: doc auth ssn visited' },
        { 'user_id' => 'user6', 'name' => 'IdV: doc auth verify visited' },
        { 'user_id' => 'user6', 'name' => 'IdV: doc auth verify submitted' },
        { 'user_id' => 'user6',
          'gpo_verification_pending' => '1',
          'name' => 'IdV: phone of record visited' },
        { 'user_id' => 'user6', 'name' => 'idv_enter_password_visited' },
        { 'user_id' => 'user6', 'name' => 'idv_enter_password_submitted' },
        { 'user_id' => 'user6', 'name' => 'IdV: personal key submitted' },
        { 'user_id' => 'user6', 'identity_verified' => '0', 'name' => 'IdV: final resolution' },

        # finishes funnel but has to wait for IPP
        { 'user_id' => 'user7', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user7', 'name' => 'IdV: doc auth welcome submitted' },
        { 'user_id' => 'user7', 'name' => 'IdV: doc auth image upload vendor submitted' },
        { 'user_id' => 'user7', 'name' => 'IdV: doc auth document_capture visited' },
        { 'user_id' => 'user7', 'name' => 'IdV: doc auth ssn visited' },
        { 'user_id' => 'user7', 'name' => 'IdV: doc auth verify visited' },
        { 'user_id' => 'user7',
          'in_person_verification_pending' => '1',
          'name' => 'IdV: doc auth verify submitted' },
        { 'user_id' => 'user7', 'name' => 'IdV: phone of record visited' },
        { 'user_id' => 'user7', 'name' => 'idv_enter_password_visited' },
        { 'user_id' => 'user7', 'name' => 'idv_enter_password_submitted' },
        { 'user_id' => 'user7', 'name' => 'IdV: personal key submitted' },
        { 'user_id' => 'user7', 'name' => 'IdV: final resolution' },

        # finishes funnel but has to wait for fraud review
        { 'user_id' => 'user8', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user8', 'name' => 'IdV: doc auth welcome submitted' },
        { 'user_id' => 'user8', 'name' => 'IdV: doc auth image upload vendor submitted' },
        { 'user_id' => 'user8', 'name' => 'IdV: doc auth document_capture visited' },
        { 'user_id' => 'user8', 'name' => 'IdV: doc auth ssn visited' },
        { 'user_id' => 'user8', 'name' => 'IdV: doc auth verify visited' },
        { 'user_id' => 'user8',
          'fraud_review_pending' => '1',
          'name' => 'IdV: doc auth verify submitted' },
        { 'user_id' => 'user8', 'name' => 'IdV: phone of record visited' },
        { 'user_id' => 'user8', 'name' => 'idv_enter_password_visited' },
        { 'user_id' => 'user8', 'name' => 'idv_enter_password_submitted' },
        { 'user_id' => 'user8', 'name' => 'IdV: personal key submitted' },
        { 'user_id' => 'user8', 'name' => 'IdV: final resolution' },
      ],
      [
        # IPP successes
        { 'user_id' => 'user9',
          'name' => 'GetUspsProofingResultsJob: Enrollment status updated',
          'success' => '1' },
        { 'user_id' => 'user10',
          'name' => 'GetUspsProofingResultsJob: Enrollment status updated',
          'success' => '1' },
        { 'user_id' => 'user11',
          'name' => 'GetUspsProofingResultsJob: Enrollment status updated',
          'success' => '1' },
        { 'user_id' => 'user12',
          'name' => 'GetUspsProofingResultsJob: Enrollment status updated',
          'success' => '1' },
      ],
    )
  end

  describe '#as_tables' do
    it 'generates the tabular csv data' do
      expect(report.as_tables).to eq expected_tables
    end
  end

  describe '#as_emailable_reports' do
    it 'adds a "first row" hash with a title for tables_report mailer' do
      reports = report.as_emailable_reports
      aggregate_failures do
        reports.each do |report|
          expect(report.title).to be_present
        end
      end
    end
  end

  describe '#to_csvs' do
    it 'generates a csv' do
      csv_string_list = report.to_csvs
      expect(csv_string_list.count).to be 3

      csvs = csv_string_list.map { |csv| CSV.parse(csv) }

      aggregate_failures do
        csvs.map(&:to_a).zip(expected_tables(strings: true)).each do |actual, expected|
          expect(actual).to eq(expected)
        end
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

  context 'no available events' do
    before do
      stub_multiple_cloudwatch_logs([], [])
    end

    it 'tries its best' do
      expect(report.as_tables).to eq(empty_tables)
      expect(report.as_emailable_reports.map(&:table)).to eq(empty_tables)
    end
  end

  def empty_tables(strings: false)
    data = [
      [0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0],
      [0],
    ]
    expected_tables(strings:, values: data)
  end

  def expected_tables(strings: false, values: nil)
    iterator = values&.each
    [
      # the first two tables are relatively static
      Reporting::DropOffReport::STEP_DEFINITIONS,
      [
        ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"],
        ['Report Generated', Date.today.to_s], # rubocop:disable Rails/Date
        ['Issuer', issuer],
      ],
      [
        ['Step', 'Unique user count', 'Users lost', 'Dropoff from last step',
         'Users left from start'],
        ['Welcome (page viewed)'] + string_or_num(strings, *(values ? iterator.next : [8])),
        ['User agreement (page viewed)'] + string_or_num(
          strings,
          *(values ? iterator.next : [8, 0, 0.0, 1.0]),
        ),
        ['Capture Document (page viewed)'] + string_or_num(
          strings,
          *(values ? iterator.next : [7, 1, 0.125, 0.875]),
        ),
        ['Document submitted (event)'] + string_or_num(
          strings,
          *(values ? iterator.next : [7, 0, 0.0, 0.875]),
        ),
        ['SSN (page view)'] + string_or_num(
          strings,
          *(values ? iterator.next : [6, 1, 1.0 / 7, 0.75]),
        ),
        ['Verify Info (page view)'] + string_or_num(
          strings,
          *(values ? iterator.next : [5, 1, 1.0 / 6, 0.625]),
        ),
        ['Verify submit (event)'] + string_or_num(
          strings,
          *(values ? iterator.next : [5, 0, 0.0, 0.625]),
        ),
        ['Phone finder (page view)'] + string_or_num(
          strings,
          *(values ? iterator.next : [5, 0, 0.0, 0.625]),
        ),
        ['Encrypt account: enter password (page view)'] + string_or_num(
          strings,
          *(values ? iterator.next : [4, 1, 0.2, 0.5]),
        ),
        ['Personal key input (page view)'] + string_or_num(
          strings,
          *(values ? iterator.next : [4, 0, 0.0, 0.5]),
        ),
        ['Verified (event)'] + string_or_num(
          strings,
          *(values ? iterator.next : [1, 3, 0.75, 0.125]),
        ),
        ['Workflow Complete - Total Pending'] + string_or_num(
          strings,
          *(values ? iterator.next : [3]),
        ),
        ['Successfully verified via in-person proofing'] + string_or_num(
          strings,
          *(values ? iterator.next : [4]),
        ),
      ],
    ]
  end

  def string_or_num(strings, *values)
    strings ? values.map(&:to_s) : values
  end
end
