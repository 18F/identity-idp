require 'rails_helper'

describe Db::ServiceProviderQuotaLimit::AnySpOverQuotaLimit do
  subject { described_class }
  let(:issuer) { 'foo' }

  context 'with an sp over their quota limit' do
    before do
      ServiceProviderQuotaLimit.create(issuer: issuer, ial: 2, percent_full: 100)
    end

    it 'it returns true' do
      expect(subject.call).to be_truthy
    end
  end

  context 'with no sp over their quota limit' do
    before do
      ServiceProviderQuotaLimit.create(issuer: issuer, ial: 2, percent_full: 99)
    end

    it 'it returns false' do
      expect(subject.call).to be_falsey
    end
  end
end
