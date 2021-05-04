require 'rails_helper'

describe Reports::SpActiveUsersOverPeriodOfPerformanceReport do
  subject { described_class.new }

  let(:issuer) { 'foo' }
  let(:issuer2) { 'foo2' }
  let(:app_id) { 'app' }

  it 'is empty' do
    expect(subject.call).to eq('[]')
  end

  it 'returns total active user counts per sp broken down by ial1 and ial2' do
    now = Time.zone.now
    service_provider = ServiceProvider.create(
      issuer: issuer,
      friendly_name: issuer,
      app_id: app_id,
      iaa_start_date: now - 6.months,
      iaa_end_date: now + 6.months,
    )
    create(
      :sp_return_log,
      user_id: 1,
      service_provider: service_provider,
      ial: 1,
      returned_at: now,
    )
    create(
      :sp_return_log,
      user_id: 1,
      service_provider: service_provider,
      ial: 2,
      returned_at: now,
    )
    create(
      :sp_return_log,
      user_id: 2,
      service_provider: service_provider,
      ial: 1,
      returned_at: now,
    )
    create(
      :sp_return_log,
      user_id: 3,
      service_provider: service_provider,
      ial: 2,
      returned_at: now,
    )
    create(
      :sp_return_log,
      user_id: 4,
      service_provider: service_provider,
      ial: 2,
      returned_at: now,
    )

    result = subject.call

    expect(JSON.parse(result, symbolize_names: true)).to eq(
      [{
        issuer: issuer,
        app_id: app_id,
        iaa: service_provider.iaa,
        total_ial1_active: 2,
        total_ial2_active: 3,
        iaa_start_date: service_provider.iaa_start_date.to_s,
        iaa_end_date: service_provider.iaa_end_date.to_s,
      }],
    )
  end
end
