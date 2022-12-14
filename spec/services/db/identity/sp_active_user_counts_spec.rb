require 'rails_helper'

describe Db::Identity::SpActiveUserCounts do
  subject { described_class }

  let(:fiscal_start_date) { 1.year.ago }
  let(:issuer) { 'foo' }
  let(:issuer2) { 'foo2' }
  let(:app_id1) { 'app1' }
  let(:app_id2) { 'app2' }

  it 'is empty' do
    expect(subject.call(fiscal_start_date).ntuples).to eq(0)
  end

  it 'returns total active user counts per sp broken down by ial1 and ial2 for ial1 only sps' do
    now = Time.zone.now
    ServiceProvider.create(issuer: issuer, friendly_name: issuer, app_id: 'app1')
    ServiceProvider.create(issuer: issuer2, friendly_name: issuer2, app_id: 'app2')
    ServiceProviderIdentity.create(
      user_id: 1, service_provider: issuer, uuid: 'foo1',
      last_ial1_authenticated_at: now
    )
    ServiceProviderIdentity.create(
      user_id: 2, service_provider: issuer, uuid: 'foo2',
      last_ial1_authenticated_at: now
    )
    ServiceProviderIdentity.create(
      user_id: 3, service_provider: issuer2, uuid: 'foo3',
      last_ial1_authenticated_at: now
    )
    result = { issuer: issuer, app_id: app_id1, total_ial1_active: 2, total_ial2_active: 0 }.to_json
    result2 = { issuer: issuer2,
                app_id: app_id2,
                total_ial1_active: 1,
                total_ial2_active: 0 }.to_json

    tuples = subject.call(fiscal_start_date)
    expect(tuples.ntuples).to eq(2)
    expect(tuples[0].to_json).to eq(result)
    expect(tuples[1].to_json).to eq(result2)
  end

  it 'returns total active user counts per sp broken down by ial1 and ial2 for ial2 only sps' do
    now = Time.zone.now
    ServiceProvider.create(issuer: issuer, friendly_name: issuer, app_id: 'app1')
    ServiceProvider.create(issuer: issuer2, friendly_name: issuer2, app_id: 'app2')
    ServiceProviderIdentity.create(
      user_id: 1, service_provider: issuer, uuid: 'foo1',
      last_ial2_authenticated_at: now
    )
    ServiceProviderIdentity.create(
      user_id: 2, service_provider: issuer, uuid: 'foo2',
      last_ial2_authenticated_at: now
    )
    ServiceProviderIdentity.create(
      user_id: 3, service_provider: issuer2, uuid: 'foo3',
      last_ial2_authenticated_at: now
    )
    result = { issuer: issuer, app_id: app_id1, total_ial1_active: 0, total_ial2_active: 2 }.to_json
    result2 = { issuer: issuer2,
                app_id: app_id2,
                total_ial1_active: 0,
                total_ial2_active: 1 }.to_json

    tuples = subject.call(fiscal_start_date)
    expect(tuples.ntuples).to eq(2)
    expect(tuples[0].to_json).to eq(result)
    expect(tuples[1].to_json).to eq(result2)
  end

  it 'returns total active user counts per sp broken down by ial1 and ial2 for ial1 ial2 sps' do
    now = Time.zone.now
    ServiceProvider.create(issuer: issuer, friendly_name: issuer, app_id: 'app1')
    ServiceProvider.create(issuer: issuer2, friendly_name: issuer2, app_id: 'app2')
    ServiceProviderIdentity.create(
      user_id: 1, service_provider: issuer, uuid: 'foo1',
      last_ial1_authenticated_at: now, last_ial2_authenticated_at: now
    )
    ServiceProviderIdentity.create(
      user_id: 2, service_provider: issuer, uuid: 'foo2',
      last_ial1_authenticated_at: now
    )
    ServiceProviderIdentity.create(
      user_id: 3, service_provider: issuer2, uuid: 'foo3',
      last_ial1_authenticated_at: now, last_ial2_authenticated_at: now
    )
    ServiceProviderIdentity.create(
      user_id: 4, service_provider: issuer2, uuid: 'foo4',
      last_ial2_authenticated_at: now
    )
    result = { issuer: issuer, app_id: app_id1, total_ial1_active: 2, total_ial2_active: 1 }.to_json
    result2 = { issuer: issuer2,
                app_id: app_id2,
                total_ial1_active: 1,
                total_ial2_active: 2 }.to_json

    tuples = subject.call(fiscal_start_date)
    expect(tuples.ntuples).to eq(2)
    expect(tuples[0].to_json).to eq(result)
    expect(tuples[1].to_json).to eq(result2)
  end
end
