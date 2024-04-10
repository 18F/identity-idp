require 'rails_helper'

RSpec.describe Reports::DropOffReport do
  let(:report_date) { Date.new(2023, 12, 12).in_time_zone('UTC') }
  let(:report_config) do
    '[{"email":"ursula@example.com",
       "issuers":"urn:gov:gsa:openidconnect.profiles:sp:sso:agency_name:app_name"}]'
  end

  before do
    allow(IdentityConfig.store).to receive(:drop_off_report_config).and_return(report_config)
  end

  describe '#perform' do
    it 'gets a CSV from the report maker, and sends email' do
      # rubocop:disable Layout/LineLength
      reports = Reporting::EmailableReport.new(
        title: 'Drop Off Report',
        table: [
          ['Term', 'Description', 'Definition', 'Calculated'],
          ['Blanket Proofing', '"Full funnel: People who started proofing from welcome screen',
           ' successfully got verified credential and encrypted account"', 'Percentage of users that successfully proofed over the total number of users that began the proofing process', '"Steps: ""Verified"" divided by ""User agreement"""'],
          ['Actual Proofing', 'Proofing funnel: People that submit and get verified',
           '"Percentage of users who submitted documents', ' passed instant verify and phone finder"', '"Steps: ""Encrypt account: enter password"" divided by ""Document submitted"""'],
          ['Verified Proofing', '"Proofing + encryption: People that get verified',
           ' encypt account and are passed back to Service Provider"', '"Number of users who submitted documents', ' passed instant verify and phone finder', ' encrypted account', ' and sent to consent screen for sharing data with Service Provider"', '"Steps: ""Verified"" divided by ""Document submitted"""'],
          ['Step', 'Definition'],
          ['Welcome (page viewed)', 'Start of proofing process'],
          ['User agreement (page viewer)', '"Users who clicked ""Continue"" on the welcome page"'],
          ['Capture Document (page viewed)',
           '"Users who check the consent checkbox and click ""Continue"""'],
          ['Document submitted (event)',
           '"Users who upload a front and back image and click ""Submit""  "'],
          ['SSN (page view)', 'Users whose ID is authenticated by Acuant'],
          ['Verify Info (page view)', 'Users who enter an SSN and continue'],
          ['Verify submit (event)',
           'Users who verify their information and submit it for Identity Verification (LN)'],
          ['Phone finder (page view)', 'Users who successfuly had their identities verified by LN'],
          ['Encrypt account: enter password (page view)',
           'Users who were able to complete the physicality check using PhoneFinder'],
          ['Personal key input (page view)', 'Users who enter their password to encrypt their PII'],
          ['USPS letter enqueued (event)',
           'Users who requested a verification letter mailed to their address.'],
          ['Verified (event)',
           'Users who confirm their personal key and complete setting up their verified account'],
          ['Report Timeframe', '2023-12-01 00:00:00 UTC to 2023-12-01 23:59:59 UTC'],
          ['Report Generated', '2024-03-25'],
          ['Issuer', 'https://eauth.va.gov/isam/sps/saml20sp/saml20'],
          ['Step', 'Unique user count', 'Users lost', 'Dropoff from last step',
           'Users left from start'],
          ['Welcome (page viewed)', '5490'],
          ['User agreement (page viewed)', '4901', '589', '0.10728597449908925',
           '0.8927140255009107'],
          ['Capture Document (page viewed)', '4424', '477', '0.09732707610691696',
           '0.8058287795992713'],
          ['Document submitted (event)', '3619', '805', '0.1819620253164557', '0.6591985428051002'],
          ['SSN (page view)', '2732', '887', '0.24509533020171317', '0.497632058287796'],
          ['Verify Info (page view)', '2713', '19', '0.006954612005856516', '0.4941712204007286'],
          ['Verify submit (event)', '2705', '8', '0.002948765204570586', '0.49271402550091076'],
          ['Phone finder (page view)', '2548', '157', '0.05804066543438078', '0.46411657559198544'],
          ['Encrypt account: enter password (page view)', '2385', '163', '0.06397174254317112',
           '0.4344262295081967'],
          ['Personal key input (page view)', '2368', '17', '0.007127882599580713',
           '0.4313296903460838'],
          ['USPS letter enqueued (event)', '201', '2167', '0.9151182432432432',
           '0.0366120218579235'],
          ['Verified (event)', '2106', '262', '0.11064189189189189', '0.3836065573770492'],
        ],
        filename: 'drop_off_report',
      )
      # rubocop:enable Layout/LineLength

      report_maker = double(
        Reporting::DropOffReport,
        to_csvs: 'I am a CSV, see',
        as_emailable_reports: reports,
      )

      allow(subject).to receive(:report_maker).and_return(report_maker)

      expect(ReportMailer).to receive(:tables_report).once.with(
        email: 'ursula@example.com',
        subject: 'Drop Off Report - 2023-12-12',
        reports: anything,
        message: anything,
        attachment_format: :csv,
      ).and_call_original

      subject.perform(report_date)
    end
  end

  describe '#report_maker' do
    it 'is a drop off report maker with the right time range' do
      report_date = Date.new(2023, 12, 25).in_time_zone('UTC')

      subject.report_date = report_date

      expect(subject.report_maker([]).time_range).to eq(report_date.all_month)
    end
  end
end
