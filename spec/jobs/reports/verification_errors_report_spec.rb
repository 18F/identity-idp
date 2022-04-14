require 'rails_helper'

describe Reports::VerificationErrorsReport do
  let(:issuer) { 'urn:gov:gsa:openidconnect:sp:sinatra' }
  let(:email) { 'foo@bar.com' }
  let(:name) { 'An SP' }
  let(:user) { create(:user) }
  let(:uuid) { 'foo' }

  subject { described_class.new }

  it 'is does not send out an email with nothing configured' do
    expect(UserMailer).to_not receive(:verification_errors_report)

    subject.perform(Time.zone.today)
  end

  it 'sends out a blank report if no users went through doc auth' do
    run_report_and_expect('')
  end

  it 'sends out an abandon code on a user lands on welcome and leaves' do
    now = Time.zone.now
    DocAuthLog.create(user_id: user.id, welcome_view_at: now, issuer: issuer)

    run_report_and_expect("#{uuid},#{now.utc},ABANDON\r\n")
  end

  it 'sends out a document error if the user submits document but does not progress forward' do
    now = Time.zone.now
    DocAuthLog.create(
      user_id: user.id,
      welcome_view_at: now,
      document_capture_submit_at: now + 1.second,
      issuer: issuer,
    )

    run_report_and_expect("#{uuid},#{now.utc},DOCUMENT_FAIL\r\n")
  end

  it 'sends out a verify error if the user submits PII but does not progress forward' do
    now = Time.zone.now
    DocAuthLog.create(
      user_id: user.id,
      welcome_view_at: now,
      verify_submit_at: now + 1.second,
      issuer: issuer,
    )

    run_report_and_expect("#{uuid},#{now.utc},VERIFY_FAIL\r\n")
  end

  it 'sends out a phone error if the user submits phone info but does not progress forward' do
    now = Time.zone.now
    DocAuthLog.create(
      user_id: user.id,
      welcome_view_at: now,
      verify_phone_submit_at: now + 1.second,
      issuer: issuer,
    )

    run_report_and_expect("#{uuid},#{now.utc},PHONE_FAIL\r\n")
  end

  describe '#good_job_concurrency_key' do
    let(:date) { Time.zone.today }

    it 'is the job name and the date' do
      job = described_class.new(date)
      expect(job.good_job_concurrency_key).
        to eq("#{described_class::REPORT_NAME}-#{date}")
    end
  end

  def run_report_and_expect(report)
    ServiceProvider.create(issuer: issuer, agency_id: 1, friendly_name: issuer)
    AgencyIdentity.create(agency_id: 1, user_id: user.id, uuid: uuid)

    allow(IdentityConfig.store).to receive(:verification_errors_report_configs).and_return(
      [{ 'name' => name, 'issuers' => [issuer], 'emails' => [email] }],
    )
    allow(UserMailer).to receive(:verification_errors_report).and_call_original

    expect(UserMailer).to receive(:verification_errors_report).with(
      email: email, name: name, issuers: [issuer], data: report,
    )

    Reports::VerificationErrorsReport.new.perform(Time.zone.today)
  end
end
