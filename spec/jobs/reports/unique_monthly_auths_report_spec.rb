require 'rails_helper'

describe Reports::UniqueMonthlyAuthsReport do
  subject { described_class.new }

  let(:issuer) { 'foo' }
  let(:app_id) { 'app_id' }
  let(:year_month) { '201901' }

  it 'is empty' do
    expect(subject.perform(Time.zone.today)).to eq('[]')
  end

  it 'returns 1 unique despite the count for the user being 7' do
    ServiceProvider.create(issuer: issuer, friendly_name: issuer, app_id: app_id)
    MonthlySpAuthCount.create(
      issuer: issuer, ial: 1, year_month: '201901', user_id: 2,
      auth_count: 7
    )
    result = [{ issuer: 'foo', year_month: '201901', app_id: app_id, total: 1 }].to_json

    expect(subject.perform(Time.zone.today)).to eq(result)
  end
end
