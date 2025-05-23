require 'rails_helper'

RSpec.describe Reports::IrsMonthlyCredMetricsReport do
  let(:report_date) { Date.new(2021, 3, 2).in_time_zone('UTC').end_of_day }
  subject(:report) { Reports::IrsMonthlyCredMetricsReport.new(report_date) }

  before do
    clear_agreements_data
    ServiceProvider.delete_all
  end

  let(:name) { 'irs_monthly_cred_metrics' }
  let(:s3_report_bucket_prefix) { 'reports-bucket' }
  let(:report_folder) do
    'int/irs_monthly_cred_metrics/2021/2021-03-02.irs_monthly_cred_metrics'
  end

  let(:expected_s3_paths) do
    [
      "#{report_folder}/irs_monthly_cred_metrics.csv",
      "#{report_folder}/irs_monthly_cred_overview.csv",
      "#{report_folder}/irs_monthly_cred_definitions.csv",
    ]
  end
  let(:s3_metadata) do
    {
      body: anything,
      content_type: 'text/csv',
      bucket: 'reports-bucket.1234-us-west-1',
    }
  end

  let(:mock_daily_reports_emails) { ['mock_irs@example.com'] }

  context 'with data generates reports by iaa + order number, issuer and year_month' do
    context 'with an IAA with a single issuer in April 2020' do
      let(:partner_account1) { create(:partner_account) }
      let(:iaa1_range) { DateTime.new(2020, 4, 15).utc..DateTime.new(2021, 4, 14).utc }

      let(:gtc1) do
        create(
          :iaa_gtc,
          gtc_number: 'gtc1234',
          partner_account: partner_account1,
          start_date: iaa1_range.begin,
          end_date: iaa1_range.end,
        )
      end

      let(:iaa1) { 'iaa1' }

      let(:iaa1_sp) do
        create(
          :service_provider,
          iaa: iaa1,
          iaa_start_date: iaa1_range.begin,
          iaa_end_date: iaa1_range.end,
        )
      end

      let(:iaa_order1) do
        build_iaa_order(order_number: 1, date_range: iaa1_range, iaa_gtc: gtc1)
      end

      let(:inside_iaa1) { iaa1_range.begin + 1.day }

      let(:user1) { create(:user, profiles: [profile1]) }
      let(:profile1) { build(:profile, verified_at: DateTime.new(2018, 6, 1).utc) }

      let(:user2) { create(:user, profiles: [profile2]) }
      let(:profile2) { build(:profile, verified_at: DateTime.new(2018, 6, 1).utc) }
      let(:report_date) { inside_iaa1 }

      let(:csv) do
        travel_to report_date do
          print("Testing auth counts!")
          report.perform(report_date)
        end
      end

      before do
        iaa_order1.integrations << build_integration(
          issuer: iaa1_sp.issuer,
          partner_account: partner_account1,
        )
        iaa_order1.save

        # 1 new unique user in month 1 at IAA 1 sp @ IAL 1
        7.times do
          create_sp_return_log(
            user: user1,
            issuer: iaa1_sp.issuer,
            ial: 1,
            returned_at: inside_iaa1,
          )
        end

        # 2 new unique users in month 1 at IAA 1 sp @ IAL 2 with profile age 2
        # user1 is both IAL1 and IAL2
        [user1, user2].each do |user|
          create_sp_return_log(
            user: user,
            issuer: iaa1_sp.issuer,
            ial: 2,
            returned_at: inside_iaa1,
          )
        end
      end

      it 'checks authentication counts in ial1 + ial2 & checks partner single issuer cases' do
        expect(csv.length).to eq(1)
        aggregate_failures do
          row = csv.find { |r| r['issuer'] == iaa1_sp.issuer }
          expect(row['iaa_order_number']).to eq('gtc1234-0001')
          expect(row['iaa_start_date']).to eq('2020-04-15')
          expect(row['iaa_end_date']).to eq('2021-04-14')
          expect(row['credentials_authorized_requesting_agency'].to_i).to eq(9)
          expect(row['new_identity_verification_credentials_authorized_for_partner'].to_i).to eq(2)
          expect(row['existing_identity_verification_credentials_authorized_for_partner'].to_i).to eq(0)
        end
      end
    end
end

  before do
    # App config/environment
    allow(Identity::Hostdata).to receive(:env).and_return('int')
    allow(Identity::Hostdata).to receive(:aws_account_id).and_return('1234')
    allow(Identity::Hostdata).to receive(:aws_region).and_return('us-west-1')
    allow(IdentityConfig.store).to receive(:s3_report_bucket_prefix).and_return(s3_report_bucket_prefix)
    allow(IdentityConfig.store).to receive(:irs_credentials_emails).and_return(mock_daily_reports_emails)

    # S3 stub
    Aws.config[:s3] = {
      stub_responses: {
        put_object: {},
      },
    }

    allow(IdentityConfig.store).to receive(:irs_credentials_emails)
      .and_return(mock_daily_reports_emails)
    
  end



  context 'the beginning of the month, it sends records for previous month' do
    let(:report_date) { Date.new(2021, 3, 1).prev_day }

    it 'returns a CSV with expected headers and rows from fake iaas data' do
      # Create a fake `iaas` object with a `.results` method
      fake_iaas = instance_double('IrsAttemptsApiLogCollection')
      fake_results = [
        { user_id: 1, success: true, count: 5 },
        { user_id: 2, success: false, count: 3 },
      ]

      allow(fake_iaas).to receive(:results).and_return(fake_results)

      csv_table = report.send(:build_csv, fake_iaas, nil ,report_date)

      expect(csv_table).to be_a(CSV::Table)

      # Check headers
      expect(csv_table.headers).to match_array([:user_id, :success, :count])

      # Check contents
      expect(csv_table.length).to eq(2)
      expect(csv_table[0][:user_id]).to eq(1)
      expect(csv_table[0][:success]).to eq(true)
      expect(csv_table[0][:count]).to eq(5)
    end

    it 'sends out a report to IRS' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        email: ['mock_irs@example.com'],
        subject: 'IRS Monthly Credential Metrics - 2021-02-28',
        reports: anything,
        message: report.preamble,
        attachment_format: :csv,
      ).and_call_original

      #report.perform(report_date)
    end
  end

  it 'does not send the report if no emails are configured' do
    allow(IdentityConfig.store).to receive(:irs_credentials_emails).and_return('')
    expect(ReportMailer).not_to receive(:tables_report)
    expect(report).not_to receive(:reports)
    #report.perform(report_date)
  end

  it 'uploads a file to S3 based on the report date' do
    expected_s3_paths.each do |path|
      expect(report).to receive(:upload_file_to_s3_bucket).with(
        path: path,
        **s3_metadata,
      ).exactly(1).time.and_call_original
    end

    #report.perform(report_date)
  end



  describe '#preamble' do
    let(:env) { 'prod' }
    subject(:preamble) { report.preamble(env:) }

    it 'is valid HTML' do
      expect(preamble).to be_html_safe
      expect { Nokogiri::XML(preamble) { |c| c.strict } }.not_to raise_error
    end


    context 'in a non-prod environment' do
      let(:env) { 'staging' }
      it 'has an alert with the environment name' do
        expect(preamble).to be_html_safe
        doc = Nokogiri::XML(preamble)
        alert = doc.at_css('.usa-alert')
        expect(alert.text).to include(env)
      end
    end
  end

  def build_iaa_order(order_number:, date_range:, iaa_gtc:)
    create(
      :iaa_order,
      order_number: order_number,
      start_date: date_range.begin,
      end_date: date_range.end,
      iaa_gtc: iaa_gtc,
    )
  end

  def build_integration(issuer:, partner_account:)
    create(
      :integration,
      issuer: issuer,
      partner_account: partner_account,
    )
  end

  def create_sp_return_log(user:, issuer:, ial:, returned_at:)
    create(
      :sp_return_log,
      user_id: user.id,
      issuer: issuer,
      ial: ial,
      returned_at: returned_at,
      profile_verified_at: user.profiles.map(&:verified_at).max,
      billable: true,
    )
  end
end