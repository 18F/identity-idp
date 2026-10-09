require 'rails_helper'

RSpec.describe Reports::SpUserCountsReport do
  subject { Reports::SpUserCountsReport.new }

  let(:app_id) { 'app_id' }
  let(:app_id2) { 'app_id2' }
  let(:sp) { create(:service_provider, app_id:) }
  let(:sp2) { create(:service_provider, app_id: app_id2) }
  let(:issuer) { sp.issuer }
  let(:issuer2) { sp2.issuer }
  let(:user1) { create(:user) }
  let(:user2) { create(:user) }
  let(:user3) { create(:user) }

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
    create(:service_provider_identity, user_id: user1.id, service_provider: issuer)
    create(:service_provider_identity, user_id: user2.id, service_provider: issuer)
    create(
      :service_provider_identity, :verified, user_id: user3.id, service_provider: issuer
    )

    create(:service_provider_identity, user_id: user1.id, service_provider: issuer2)

    expected = [
      {
        issuer: issuer,
        total: 3,
        ial1_total: 2,
        ial2_total: 1,
        app_id: app_id,
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
