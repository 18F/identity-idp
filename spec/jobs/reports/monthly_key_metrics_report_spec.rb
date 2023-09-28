require 'rails_helper'

RSpec.describe Reports::MonthlyKeyMetricsReport do
  subject(:report) { Reports::MonthlyKeyMetricsReport.new }

  let(:report_date) { Date.new(2021, 3, 2) }
  let(:name) { 'monthly-key-metrics-report' }
  let(:agnes_email) { 'fake@agnes_email.com' }
  let(:feds_email) { 'fake@feds_email.com' }

  before do
    allow(IdentityConfig.store).to receive(:team_agnes_email).
      and_return(agnes_email)
    allow(IdentityConfig.store).to receive(:team_all_feds_email).
      and_return(feds_email)
  end

  it 'sends out a report to the email listed with one total user' do
    expect(ReportMailer).to receive(:tables_report).once.with(
      message: 'Report: monthly-key-metrics-report 2021-03-02',
      email: [agnes_email],
      subject: 'Monthly Key Metrics Report - 2021-03-02',
      tables: anything,
    ).and_call_original

    subject.perform(report_date)
  end

  it 'sends out a report to the emails listed with two users' do
    first_of_month_date = report_date - 1

    expect(ReportMailer).to receive(:tables_report).once.with(
      message: 'Report: monthly-key-metrics-report 2021-03-01',
      email: [agnes_email, feds_email],
      subject: 'Monthly Key Metrics Report - 2021-03-01',
      tables: anything,
    ).and_call_original

    subject.perform(first_of_month_date)
  end

  it 'does not send out a report with no emails' do
    allow(IdentityConfig.store).to receive(:team_agnes_email).and_return('')

    expect(ReportMailer).not_to receive(:tables_report).with(
      message: 'Report: monthly-key-metrics-report 2021-03-02',
      email: [''],
      subject: 'Monthly Key Metrics Report - 2021-03-02',
      tables: anything,
    ).and_call_original

    subject.perform(report_date)
  end
end
