require 'rails_helper'

RSpec.describe Reports::MonthlyKeyMetricsReport do
  subject(:report) { Reports::MonthlyKeyMetricsReport.new }

  let(:report_date) { Date.new(2021, 3, 2) }
  let(:name) { 'monthly-key-metrics-report' }
  let(:email) { 'fake@email.com' }

  it 'sends out a report to the email listed with one total user' do
    allow(IdentityConfig.store).to receive(:monthly_key_metrics_report_configs_configs).and_return(
      [{ 'emails' => [email] }],
    )
    expected_csv =
      "IDV app reuse rate Feb-2021\nNum. SPs,Num. users,Percentage\nTotal (all >1),0,0\n\nTotal proofed identities\nTotal proofed identities (Feb-2021),0\n"
    expect(ReportMailer).to receive(:monthly_key_metrics_report).with(
      name: name, email: email, csv_report: expected_csv,
    ).and_call_original

    subject.perform(report_date)
  end
end
