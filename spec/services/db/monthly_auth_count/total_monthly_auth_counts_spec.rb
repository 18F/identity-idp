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
    7.times do
      create(
        :sp_return_log,
        issuer: issuer,
        ial: 1,
        user_id: 2,
        requested_at: Date.new(2019, 1, 15),
        returned_at: Date.new(2019, 1, 15),
        billable: true,
      )
    end
    3.times do
      create(
        :sp_return_log,
        issuer: issuer,
        ial: 1,
        user_id: 3,
        requested_at: Date.new(2019, 1, 15),
        returned_at: Date.new(2019, 1, 15),
        billable: true,
      )
    end
    result = { issuer: issuer, ial: 1, year_month: year_month, total: 10, app_id: app_id }.to_json

    expect(subject.call.ntuples).to eq(1)
    expect(subject.call[0].to_json).to eq(result)
  end
end
