require 'rails_helper'

describe Db::MonthlySpAuthCount::TotalMonthlyAuthCounts do
  subject { described_class }

  let(:issuer) { 'foo' }
  let(:app_id) { 'app_id' }
  let(:year_month) { '201901' }

  it 'is empty' do
    expect(subject.call.ntuples).to eq(0)
  end

  it 'returns the total auth counts' do
    ServiceProvider.create(issuer: issuer, friendly_name: issuer, app_id: app_id)
    MonthlySpAuthCount.create(
      issuer: issuer, ial: 1, year_month: year_month, user_id: 2,
      auth_count: 7
    )
    MonthlySpAuthCount.create(
      issuer: issuer, ial: 1, year_month: year_month, user_id: 3,
      auth_count: 3
    )
    result = { issuer: issuer, ial: 1, year_month: year_month, total: 10, app_id: app_id }.to_json

    expect(subject.call.ntuples).to eq(1)
    expect(subject.call[0].to_json).to eq(result)
  end
end
