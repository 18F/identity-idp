require 'rails_helper'

describe Db::Identity::SpUserQuotas do
  subject { described_class }

  let(:issuer) { 'foo' }
  let(:issuer2) { 'foo2' }
  let(:app_id) { 'app_id' }
  let(:app_id2) { 'app_id2' }
  let(:fiscal_start_date) { 1.year.ago.strftime('%m-%d-%Y') }

  it 'is empty' do
    expect(subject.call(fiscal_start_date).ntuples).to eq(0)
  end

  it 'returns the total ial2 user count per fiscal year with percent ial2 quota' do
    ServiceProvider.create(issuer: issuer, friendly_name: issuer, app_id: app_id)
    ServiceProvider.create(issuer: issuer2, friendly_name: issuer2, ial2_quota: 1,
                           app_id: app_id2)
    Identity.create(user_id: 1, service_provider: issuer, uuid: 'foo1')
    Identity.create(user_id: 2, service_provider: issuer, uuid: 'foo2')
    Identity.create(user_id: 3, service_provider: issuer, uuid: 'foo3', verified_at: Time.zone.now)
    Identity.create(user_id: 4, service_provider: issuer2, uuid: 'foo4', verified_at: Time.zone.now)
    result = { issuer: issuer, app_id: app_id, ial2_total: 1, percent_ial2_quota: 0 }.to_json
    result2 = { issuer: issuer2, app_id: app_id2, ial2_total: 1, percent_ial2_quota: 100 }.to_json

    tuples = subject.call(fiscal_start_date)
    expect(tuples.ntuples).to eq(2)
    expect(tuples.to_json).to include(result)
    expect(tuples.to_json).to include(result2)
  end
end
