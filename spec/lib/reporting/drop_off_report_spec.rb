require 'rails_helper'
require 'reporting/drop_off_report'

RSpec.describe Reporting::DropOffReport do
  let(:issuer) { 'my:example:issuer' }
  let(:time_range) { Date.new(2022, 1, 1).all_day }

  subject(:report) { Reporting::DropOffReport.new(issuers: [issuer], time_range:) }

  before do
    cloudwatch_client = double(
      'Reporting::CloudwatchClient',
      fetch: [
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
      ],
    )

    allow(report).to receive(:cloudwatch_client).and_return(cloudwatch_client)
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
      expect(csv_string_list.count).to be 4

      csvs = csv_string_list.map { |csv| CSV.parse(csv) }

      aggregate_failures do
        csvs.map(&:to_a).zip(expected_tables(strings: true)).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
  end

  def expected_tables(strings: false)
    [
      # these two tables are static
      report.proofing_definition_table,
      report.step_definition_table,
      [
        ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"],
        ['Report Generated', Date.today.to_s], # rubocop:disable Rails/Date
        ['Issuer', issuer],
      ],
      [
        ['Step', 'Unique user count', 'Users lost', 'Dropoff from last step',
         'Users left from start'],
        ['Welcome (page viewed)', strings ? '5' : 5],
        ['User agreement (page viewed)', strings ? '5' : 5, strings ? '0' : 0, '0.0%', '100.0%'],
        ['Capture Document (page viewed)', strings ? '4' : 4, strings ? '1' : 1, '20.0%', '80.0%'],
        ['Document submitted (event)', strings ? '4' : 4, strings ? '0' : 0, '0.0%', '80.0%'],
        ['SSN (page view)', strings ? '3' : 3, strings ? '1' : 1, '25.0%', '60.0%'],
        ['Verify Info (page view)', strings ? '2' : 2, strings ? '1' : 1, '33.33%', '40.0%'],
        ['Verify submit (event)', strings ? '2' : 2, strings ? '0' : 0, '0.0%', '40.0%'],
        ['Phone finder (page view)', strings ? '2' : 2, strings ? '0' : 0, '0.0%', '40.0%'],
        ['Encrypt account: enter password (page view)', strings ? '1' : 1, strings ? '1' : 1,
         '50.0%', '20.0%'],
        ['Personal key input (page view)', strings ? '1' : 1, strings ? '0' : 0, '0.0%', '20.0%'],
        ['Verified (event)', strings ? '1' : 1, strings ? '0' : 0, '0.0%', '20.0%'],
        ['Blanket proofing rate', '', '', '', '20.0%'],
        ['Actual proofing rate', '', '', '', '25.0%'],
        ['Verified proofing rate', '', '', '', '25.0%'],
      ],
    ]
  end
end
