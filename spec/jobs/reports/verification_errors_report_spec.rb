require 'rails_helper'

describe Reports::VerificationErrorsReport do
  let(:issuer) { 'urn:gov:gsa:openidconnect:sp:sinatra' }
  let(:email) { 'foo@bar.com' }
  let(:name) { 'An SP' }
  let(:user) { create(:user) }
  let(:uuid) { 'foo' }
  let(:user2) { create(:user) }
  let(:uuid2) { 'foo2' }

  subject { described_class.new }

  it 'is does not send out an email with nothing configured' do
    expect(UserMailer).to_not receive(:verification_errors_report)

    subject.perform(Time.zone.today)
  end

  it 'sends out a blank report if no users went through doc auth' do
    reports = run_reports

    expect(reports.length).to eq(1)
    csv = CSV.parse(reports[0])
    expect(csv.first).to eq(['uuid', 'welcome_view_at', 'error_code'])
    expect(csv.length).to eq(1)
  end

  it 'sends out an abandon code on a user lands on welcome and leaves' do
    now = Time.zone.now
    DocAuthLog.create(user_id: user.id, welcome_view_at: now, issuer: issuer)

    reports = run_reports
    expect(reports.length).to eq(1)
    csv = CSV.parse(reports[0])
    expect(csv.length).to eq(2)
    expect(csv.first).to eq(['uuid', 'welcome_view_at', 'error_code'])
    expect(csv[1]).to eq([uuid, now.to_time.utc.iso8601, 'ABANDON'])
  end

  it 'sends out a blank report if no issuer data' do
    now = Time.zone.now
    DocAuthLog.create(user_id: user.id, welcome_view_at: now, issuer: 'issuer2')

    reports = run_reports
    expect(reports.length).to eq(1)
    csv = CSV.parse(reports[0])
    expect(csv.first).to eq(['uuid', 'welcome_view_at', 'error_code'])
    expect(csv.length).to eq(1)
  end

  it 'sends out a document error if the user submits document but does not progress forward' do
    now = Time.zone.now
    DocAuthLog.create(
      user_id: user.id,
      welcome_view_at: now,
      document_capture_submit_at: now + 1.second,
      issuer: issuer,
    )

    reports = run_reports
    expect(reports.length).to eq(1)
    csv = CSV.parse(reports[0])
    expect(csv.length).to eq(2)
    expect(csv.first).to eq(['uuid', 'welcome_view_at', 'error_code'])
    expect(csv[1]).to eq([uuid, now.to_time.utc.iso8601, 'DOCUMENT_FAIL'])
  end

  it 'sends out a verify error if the user submits PII but does not progress forward' do
    now = Time.zone.now
    DocAuthLog.create(
      user_id: user.id,
      welcome_view_at: now,
      verify_submit_at: now + 1.second,
      issuer: issuer,
    )

    reports = run_reports
    expect(reports.length).to eq(1)
    csv = CSV.parse(reports[0])
    expect(csv.length).to eq(2)
    expect(csv.first).to eq(['uuid', 'welcome_view_at', 'error_code'])
    expect(csv[1]).to eq([uuid, now.to_time.utc.iso8601, 'VERIFY_FAIL'])
  end

  it 'sends out a phone error if the user submits phone info but does not progress forward' do
    now = Time.zone.now
    DocAuthLog.create(
      user_id: user.id,
      welcome_view_at: now,
      verify_phone_submit_at: now + 1.second,
      issuer: issuer,
    )

    reports = run_reports
    expect(reports.length).to eq(1)
    csv = CSV.parse(reports[0])
    expect(csv.length).to eq(2)
    expect(csv.first).to eq(['uuid', 'welcome_view_at', 'error_code'])
    expect(csv[1]).to eq([uuid, now.to_time.utc.iso8601, 'PHONE_FAIL'])
  end

  it 'sends more than one user' do
    now = Time.zone.now
    DocAuthLog.create(user_id: user2.id, welcome_view_at: now, issuer: issuer)
    AgencyIdentity.create(agency_id: 1, user_id: user2.id, uuid: uuid2)
    DocAuthLog.create(
      user_id: user.id,
      welcome_view_at: now,
      document_capture_submit_at: now + 1.second,
      issuer: issuer,
    )

    reports = run_reports
    expect(reports.length).to eq(1)
    csv = CSV.parse(reports[0])
    expect(csv.length).to eq(3)
    expect(csv.first).to eq(['uuid', 'welcome_view_at', 'error_code'])
    expect(csv[1]).to eq([uuid, now.to_time.utc.iso8601, 'DOCUMENT_FAIL'])
    expect(csv[2]).to eq([uuid2, now.to_time.utc.iso8601, 'ABANDON'])
  end

  describe '#good_job_concurrency_key' do
    let(:date) { Time.zone.today }

    it 'is the job name and the date' do
      job = described_class.new(date)
      expect(job.good_job_concurrency_key).
        to eq("#{described_class::REPORT_NAME}-#{date}")
    end
  end

  def run_reports
    ServiceProvider.create(issuer: issuer, agency_id: 1, friendly_name: issuer)
    AgencyIdentity.create(agency_id: 1, user_id: user.id, uuid: uuid)

    allow(IdentityConfig.store).to receive(:verification_errors_report_configs).and_return(
      [{ 'name' => name, 'issuers' => [issuer], 'emails' => [email] }],
    )

    Reports::VerificationErrorsReport.new.perform(Time.zone.today)
  end
end
