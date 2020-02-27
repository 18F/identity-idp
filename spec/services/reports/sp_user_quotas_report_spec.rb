require 'rails_helper'

describe Reports::SpUserQuotasReport do
  subject { described_class.new }

  let(:issuer) { 'foo' }

  it 'is empty' do
    expect(subject.call).to eq('[]')
  end

  it 'returns the total ial2 user count per fiscal year with percent ial2 quot' do
    ServiceProvider.create(issuer: issuer, friendly_name: issuer)
    Identity.create(user_id: 1, service_provider: issuer, uuid: 'foo1')
    Identity.create(user_id: 2, service_provider: issuer, uuid: 'foo2')
    Identity.create(user_id: 3, service_provider: issuer, uuid: 'foo3', verified_at: Time.zone.now)
    result = [{ issuer: issuer, ial2_total: 1, percent_ial2_quota: 0 }].to_json

    expect(subject.call).to eq(result)
  end
end
