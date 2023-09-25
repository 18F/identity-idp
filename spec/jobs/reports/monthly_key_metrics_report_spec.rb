require 'rails_helper'

RSpec.describe Reports::MonthlyKeyMetricsReport do
  subject(:report) { Reports::MonthlyKeyMetricsReport.new }

  let(:report_date) { Date.new(2021, 3, 2) }
  let(:name) { 'monthly-key-metrics-report' }
  let(:agnes_email) { 'fake@agnes_email.com' }
  let(:feds_email) { 'fake@feds_email.com' }

  before do
    allow(IdentityConfig.store).to receive(:team_agnes_email).and_return(
      agnes_email,
    )
    allow(IdentityConfig.store).to receive(:team_all_feds_email).and_return(
      feds_email,
    )
    allow(Identity::Hostdata).to receive(:env).and_return(
      'prod',
    )
  end

  it 'sends out a report to the email listed with one total user' do
    travel_to report_date

    expected_csv =
      [[{ title: 'IDV app reuse rate Feb-2021', float_as_percent: true, precision: 4 },
        ['Num. SPs', 'Num. users', 'Percentage'],
        ['Total (all >1)', 0, 0]],
       [{ title: 'Total proofed identities' },
        [['Total proofed identities (Feb-2021)'], [0]]]]

    expect(ReportMailer).to receive(:tables_report).once.with(
      message: "Report: monthly-key-metrics-report 2021-03-01", email: agnes_email, subject: "Monthly Key Metrics Report - 2021-03-01", tables: expected_csv,
    ).and_call_original

    expect(ReportMailer).not_to receive(:tables_report).with(
      message: "Report: monthly-key-metrics-report 2021-03-01", email: feds_email, subject: "Monthly Key Metrics Report - 2021-03-01", tables: expected_csv,
    ).and_call_original

    subject.perform(report_date)
  end

  it 'sends out a report to the emails listed with two users' do
    first_of_month_date = report_date-1
    travel_to first_of_month_date

    expected_csv_1 =
      [[{ title: 'IDV app reuse rate Feb-2021', float_as_percent: true, precision: 4 },
        ['Num. SPs', 'Num. users', 'Percentage'],
        ['Total (all >1)', 0, 0]],
       [{ title: 'Total proofed identities' },
        [['Total proofed identities (Feb-2021)'], [0]]]]
    expected_csv_2 =
        [[["Num. SPs", "Num. users", "Percentage"], ["Total (all >1)", 0, 0]],
            [[["Total proofed identities (Feb-2021)"], [0]]]]

    expect(ReportMailer).to receive(:tables_report).once.with(
      message: "Report: monthly-key-metrics-report 2021-03-01", email: agnes_email, subject: "Monthly Key Metrics Report - 2021-03-01", tables: expected_csv_1,
    ).and_call_original

    expect(ReportMailer).to receive(:tables_report).once.with(
      message: "Report: monthly-key-metrics-report 2021-03-01", email: feds_email, subject: "Monthly Key Metrics Report - 2021-03-01", tables: expected_csv_2,
    ).and_call_original

    subject.perform(first_of_month_date)
  end
end
