require 'rails_helper'

describe Reports::SpActiveUsersReport do
  subject { described_class.new }

  let(:fiscal_start_date) { 1.year.ago.to_s }
  let(:issuer) { 'foo' }
  let(:issuer2) { 'foo2' }
  let(:app_id) { 'app' }

  it 'is empty' do
    expect(subject.call).to eq('[]')
  end

  it 'returns total active user counts per sp broken down by ial1 and ial2' do
    now = Time.zone.now
    ServiceProvider.create(issuer: issuer, friendly_name: issuer, app_id: 'app')
    ServiceProviderIdentity.create(user_id: 1, service_provider: issuer, uuid: 'foo1',
                    last_ial1_authenticated_at: now, last_ial2_authenticated_at: now)
    ServiceProviderIdentity.create(user_id: 2, service_provider: issuer, uuid: 'foo2',
                    last_ial1_authenticated_at: now)
    ServiceProviderIdentity.create(user_id: 3, service_provider: issuer, uuid: 'foo3',
                    last_ial2_authenticated_at: now)
    ServiceProviderIdentity.create(user_id: 4, service_provider: issuer, uuid: 'foo4',
                    last_ial2_authenticated_at: now)
    result = [{ issuer: issuer, app_id: app_id, total_ial1_active: 2,
                total_ial2_active: 3 }].to_json

    expect(subject.call).to eq(result)
  end
end
