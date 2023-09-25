require 'rails_helper'

RSpec.describe Reports::MonthlyKeyMetricsReport do
  subject(:report) { Reports::MonthlyKeyMetricsReport.new }

  let(:report_date) { Date.new(2021, 3, 2) }
  let(:name) { 'monthly-key-metrics-report' }
  let(:email) { 'fake@email.com' }

  before do
    travel_to report_date
  end

  it 'sends out a report to the email listed with one total user' do
    allow(IdentityConfig.store).to receive(:monthly_key_metrics_report_configs_configs).and_return(
      [{ 'emails' => [email] }],
    )
    expected_csv =
      [[{ title: 'IDV app reuse rate Feb-2021', float_as_percent: true, precision: 4 },
        ['Num. SPs', 'Num. users', 'Percentage'],
        ['Total (all >1)', 0, 0]],
       [{ title: 'Total proofed identities' },
        ['Total proofed identities (Feb-2021)', 0]]]

    expect(ReportMailer).to receive(:monthly_key_metrics_report).with(
      name: name, email: email, month: report_date, csv_report: expected_csv,
    ).and_call_original

    subject.perform(report_date)
  end
end
