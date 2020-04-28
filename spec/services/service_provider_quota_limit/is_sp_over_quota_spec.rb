require 'rails_helper'

describe Db::ServiceProviderQuotaLimit::IsSpOverQuota do
  subject { described_class }
  let(:issuer) { 'foo' }

  context 'with an sp over their quota limit' do
    before do
      ServiceProviderQuotaLimit.create(issuer: issuer, ial: 2, percent_full: 100)
    end

    it 'it returns true' do
      expect(subject.call(issuer)).to eq(true)
    end

    it 'it returns false if it is not the sp over the limit' do
      expect(subject.call('bar')).to eq(false)
    end
  end

  context 'with no sp over their quota limit' do
    before do
      ServiceProviderQuotaLimit.create(issuer: issuer, ial: 2, percent_full: 99)
    end

    it 'it returns false' do
      expect(subject.call(issuer)).to eq(false)
    end
  end
end
