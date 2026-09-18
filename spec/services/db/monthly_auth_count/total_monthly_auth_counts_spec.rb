require 'rails_helper'

RSpec.describe Db::MonthlySpAuthCount::TotalMonthlyAuthCounts do
  subject { described_class }

  let(:app_id) { 'app_id' }
  let(:sp) { create(:service_provider, app_id:) }
  let(:issuer) { sp.issuer }
  let(:user1) { create(:user) }
  let(:user2) { create(:user) }
  let(:user3) { create(:user) }
  let(:year_month) { '201901' }

  it 'is empty' do
    expect(subject.call.length).to eq(0)
  end

  it 'returns the total auth counts' do
    7.times do
      create(
        :sp_return_log,
        issuer:,
        ial: 1,
        user_id: user1.id,
        returned_at: Date.new(2019, 1, 15),
        billable: true,
      )
    end
    3.times do
      create(
        :sp_return_log,
        issuer:,
        ial: 1,
        user_id: user2.id,
        returned_at: Date.new(2019, 1, 15),
        billable: true,
      )
    end

    2.times do
      create(
        :sp_return_log,
        issuer:,
        ial: 1,
        user_id: user3.id,
        returned_at: Date.new(2019, 2, 10),
        billable: true,
      )
    end

    first_month_result = {
      issuer:,
      ial: 1,
      year_month:,
      total: 10,
      app_id:,
    }.stringify_keys

    second_month_result = {
      issuer: issuer,
      ial: 1,
      year_month: '201902',
      total: 2,
      app_id:,
    }.stringify_keys

    result = subject.call

    expect(result.length).to eq(2)
    expect(result.first).to eq(first_month_result)
    expect(result.last).to eq(second_month_result)
  end
end
