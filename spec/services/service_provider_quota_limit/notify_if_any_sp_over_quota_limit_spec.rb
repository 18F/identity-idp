require 'rails_helper'

describe Db::ServiceProviderQuotaLimit::NotifyIfAnySpOverQuotaLimit do
  subject { described_class }
  let(:issuer) { 'foo' }
  let(:email) { 'test1@test.com' }

  context 'with an sp over their quota limit' do
    before do
      ServiceProviderQuotaLimit.create(issuer: issuer, ial: 2, percent_full: 100)
    end

    it 'notifies the emails in the email list' do
      expect(ReportMailer).to receive(:sps_over_quota_limit).with(email).and_call_original

      subject.call
    end
  end

  context 'with no sp over their quota limit' do
    before do
      ServiceProviderQuotaLimit.create(issuer: issuer, ial: 2, percent_full: 99)
    end

    it 'does not notify the emails in the email list' do
      expect(ReportMailer).to_not receive(:sps_over_quota_limit).with(email).and_call_original

      subject.call
    end
  end
end
