require 'rails_helper'

describe Db::ServiceProviderQuotaLimit::UpdateFromReport do
  subject { described_class }
  let(:issuer) { 'foo' }
  let(:percent_ial2_quota) { 90 }
  let(:report_hash) do
    [{
      'issuer' => issuer,
      'ial' => 2,
      'percent_ial2_quota' => percent_ial2_quota,
    }]
  end

  it 'creates a record if one does not exist' do
    subject.call(report_hash)

    record = ServiceProviderQuotaLimit.first
    expect(record.issuer).to eq(issuer)
    expect(record.ial).to eq(2)
    expect(record.percent_full).to eq(percent_ial2_quota)
  end

  it 'updates a record if it exists' do
    ServiceProviderQuotaLimit.create(issuer: issuer, ial: 2, percent_full: percent_ial2_quota)

    subject.call(report_hash)

    expect(ServiceProviderQuotaLimit.count).to eq(1)
    record = ServiceProviderQuotaLimit.first
    expect(record.issuer).to eq(issuer)
    expect(record.ial).to eq(2)
    expect(record.percent_full).to eq(percent_ial2_quota)
  end
end
