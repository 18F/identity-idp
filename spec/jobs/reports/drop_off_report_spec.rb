require 'rails_helper'

RSpec.describe Reports::DropOffReport do
  let(:report_date) { Date.new(2023, 12, 12).in_time_zone('UTC') }
  # This is in S3 as a string that gets parsed via identity_config.rb
  let(:report_config) do
    JSON.parse '[{"emails":["ursula@example.com"],
       "issuers":["urn:gov:gsa:openidconnect.profiles:sp:sso:agency_name:app_name"]}]'
  end
  let(:empty_emailable_report) do
    report = Reporting::DropOffReport.new(
      issuers: 'urn:gov:gsa:openidconnect.profiles:sp:sso:agency_name:app_name',
      time_range: report_date.all_week,
      slice: 1.week,
    )

    report.as_emailable_reports
  end

  before do
    allow(IdentityConfig.store).to receive(:drop_off_report_config).and_return(report_config)
  end

  describe 'with empty logs' do
    before do
      stub_cloudwatch_logs([])
    end

    it 'sends a ReportMailer with data that matches an empty Reporting::DropOffReport' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        email: 'ursula@example.com',
        subject: "Drop Off Report - #{report_date.to_date}",
        reports: satisfy do |value|
          expect(value.first).to eq(empty_emailable_report.first)
          expect(value.second).to eq(empty_emailable_report.second)
          expect(value.last.to_json).to eq(empty_emailable_report.last.to_json)
          expect(value.count).to be(3)
        end,
        message: "<h2>\n  Drop Off Report\n</h2>\n",
        attachment_format: :csv,
      ).and_call_original

      subject.perform(report_date)
    end

    context 'with a single issuer instead of an array' do
      let(:report_config) do
        [
          {
            'issuers' => 'urn:gov:gsa:openidconnect.profiles:sp:sso:agency_name:app_name',
            'emails' => ['test+test@gsa.gov'],
          },
        ]
      end
      it 'generates a report' do
        subject.perform(report_date)
      end
    end
  end

  describe 'with some log data' do
    before do
      stub_cloudwatch_logs(
        [
          # gets through phone finder, then drops
          { 'user_id' => 'user2', 'name' => 'IdV: doc auth welcome visited' },
          { 'user_id' => 'user2', 'name' => 'IdV: doc auth welcome submitted' },
          { 'user_id' => 'user2', 'name' => 'IdV: doc auth image upload vendor submitted' },
          { 'user_id' => 'user2', 'name' => 'IdV: doc auth document_capture visited' },
          { 'user_id' => 'user2', 'name' => 'IdV: doc auth ssn visited' },
          { 'user_id' => 'user2', 'name' => 'IdV: doc auth verify visited' },
          { 'user_id' => 'user2', 'name' => 'IdV: doc auth verify submitted' },
          { 'user_id' => 'user2', 'name' => 'IdV: phone of record visited' },
        ],
      )
    end

    it 'sends a mailer with the log data' do
      subject.perform(report_date)
      sent_mail = ActionMailer::Base.deliveries.last
      csv_data = CSV.parse(sent_mail.parts.last.body.to_s, headers: true)
      expect(csv_data.headers).to eq(
        [
          'Step',
          'Unique user count',
          'Users lost',
          'Dropoff from last step',
          'Users left from start',
        ],
      )

      phone_finder_index = csv_data.find_index { |row| row['Step'] == 'Phone finder (page view)' }
      phone_finder_row = csv_data[phone_finder_index]
      next_row = csv_data[phone_finder_index + 1]
      expect(phone_finder_row['Users lost']).to eq('0')
      expect(phone_finder_row['Dropoff from last step'].to_i).to eq(0)
      expect(next_row['Users lost']).to eq('1')
      expect(next_row['Dropoff from last step'].to_i).to eq(1)
    end
  end

  describe '#perform' do
    it 'gets a CSV from the report maker, and sends email' do
      reports = Reporting::EmailableReport.new(
        title: 'Drop Off Report',
        table: [
          ['Term', 'Description', 'Definition', 'Calculated'],
          ['1', '2', '3', '4'],
        ],
        filename: 'drop_off_report',
      )

      report_maker = double(
        Reporting::DropOffReport,
        to_csvs: 'I am a CSV, see',
        as_emailable_reports: reports,
      )

      allow(Reporting::DropOffReport).to receive(:new).with(
        issuers: ['urn:gov:gsa:openidconnect.profiles:sp:sso:agency_name:app_name'],
        time_range: report_date.all_week,
        slice: 1.week,
      ).and_return(report_maker)

      expect(ReportMailer).to receive(:tables_report).once.with(
        email: 'ursula@example.com',
        subject: "Drop Off Report - #{report_date.to_date}",
        reports: anything,
        message: "<h2>\n  Drop Off Report\n</h2>\n",
        attachment_format: :csv,
      ).and_call_original

      subject.perform(report_date)
    end
  end

  describe '#report_maker' do
    it 'is a drop off report maker with the right time range' do
      report_date = Date.new(2023, 12, 25).in_time_zone('UTC')

      subject.report_date = report_date

      expect(subject.report_maker([]).time_range).to eq(report_date.all_week)
    end
  end
end
