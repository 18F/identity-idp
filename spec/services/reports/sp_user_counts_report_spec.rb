require 'rails_helper'

describe Reports::SpUserCountsReport do
  subject { described_class.new }

  let(:issuer) { 'foo' }
  let(:app_id) { 'app_id' }

  it 'is empty' do
    expect(subject.call).to eq('[]')
  end

  it 'returns the total user counts per sp broken down by ial1 and ial2' do
    ServiceProvider.create(issuer: issuer, friendly_name: issuer, app_id: app_id)
    ServiceProviderIdentity.create(user_id: 1, service_provider: issuer, uuid: 'foo1')
    ServiceProviderIdentity.create(user_id: 2, service_provider: issuer, uuid: 'foo2')
    ServiceProviderIdentity.create(
      user_id: 3, service_provider: issuer, uuid: 'foo3',
      verified_at: Time.zone.now
    )
    result = [{ issuer: issuer, total: 3, ial1_total: 2, ial2_total: 1, app_id: app_id }].to_json

    expect(subject.call).to eq(result)
  end
end
