require 'rails_helper'

RSpec.describe Reports::SpIssuerUserCountsReport do
  let(:issuer) { 'urn:gov:gsa:openidconnect:sp:sinatra' }
  let(:email) { 'foo@bar.com' }
  let(:date) { Date.today.to_s }
  let(:user_counts) do
    {
      "total" => 56,
      "ial1_total" => 40,
      "ial2_total" => 16
    }
  end

  subject { described_class.new }

  let(:reports) do
    [
      Reporting::EmailableReport.new(
        title: 'Overview',
        table: [
          ['Report Generated', date],
          ['Issuer', issuer],
        ],
      ),
      Reporting::EmailableReport.new(
        title: 'User counts',
        table: [
          ['Metric', 'Number of users'],
          ['Total Users', 56],
          ['IAL1 Users', 40],
          ['Identity Verified Users', 16]
        ],
      ),
    ]
  end

  before do
    expect(Db::Identity::SpUserCounts).to receive(:with_issuer).with(issuer).
      and_return(user_counts)

    allow(IdentityConfig.store).to receive(:sp_issuer_user_counts_report_configs).
      and_return([{ 'issuer' => issuer, 'emails' => [email] }])

    allow(ReportMailer).to receive(:tables_report).and_call_original
  end


  it 'emails the csv' do
    expect(ReportMailer).to receive(:tables_report).with(
      email:,
      subject: "Service provider user count report",
      message: "Report: #{Reports::SpIssuerUserCountsReport::REPORT_NAME}",
      reports:,
      attachment_format: :csv,
    )

    subject.perform(Time.zone.today)
  end
end
