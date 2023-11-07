require 'rails_helper'

RSpec.describe Reports::SpUserCountsReport do
  subject { described_class.new }

  let(:issuer) { 'foo' }
  let(:app_id) { 'app_id' }

  it 'has overall data' do
    report = JSON.parse(subject.perform(Time.zone.today), symbolize_names: true)

    expect(report).to eq(
      [
        {
          issuer: nil,
          total: 0,
          ial1_total: 0,
          ial2_total: 0,
          app_id: nil,
        },
      ],
    )
  end

  it 'returns the total user counts per sp broken down by ial1 and ial2' do
    create(:service_provider, issuer:, app_id:)
    create(:service_provider_identity, user_id: 1, service_provider: issuer)
    create(:service_provider_identity, user_id: 2, service_provider: issuer)
    create(
      :service_provider_identity, :verified, user_id: 3, service_provider: issuer
    )

    issuer2 = 'issuer2'
    app_id2 = 'appid2'
    create(:service_provider, issuer: issuer2, app_id: app_id2)
    create(:service_provider_identity, user_id: 1, service_provider: issuer2)

    expected = [
      {
        issuer:,
        total: 3,
        ial1_total: 2,
        ial2_total: 1,
        app_id:,
      },
      {
        issuer: issuer2,
        total: 1,
        ial1_total: 1,
        ial2_total: 0,
        app_id: app_id2,
      },
      {
        issuer: nil,
        total: 3,
        ial1_total: 2,
        ial2_total: 1,
        app_id: nil,
      },
    ]

    result = JSON.parse(subject.perform(Time.zone.today), symbolize_names: true)

    expect(result).to match_array(expected)
  end
end
