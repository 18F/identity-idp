require 'rails_helper'

describe Db::MonthlySpAuthCount::TotalMonthlyAuthCounts do
  subject { described_class }

  let(:issuer) { 'foo' }
  let(:app_id) { 'app_id' }

  it 'is empty' do
    expect(subject.call.length).to eq(0)
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

    2.times do
      create(
        :sp_return_log,
        issuer: issuer,
        ial: 1,
        user_id: 3,
        requested_at: Date.new(2019, 2, 10),
        returned_at: Date.new(2019, 2, 10),
        billable: true,
      )
    end

    first_month_result = {
      issuer: issuer,
      ial: 1,
      year_month: '201901',
      total: 10,
      app_id: app_id
    }.stringify_keys

    second_month_result = {
      issuer: issuer,
      ial: 1,
      year_month: '201902',
      total: 2,
      app_id: app_id
    }.stringify_keys

    result = subject.call

    expect(result.length).to eq(2)
    expect(result.first).to eq(first_month_result)
    expect(result.last).to eq(second_month_result)
  end
end
