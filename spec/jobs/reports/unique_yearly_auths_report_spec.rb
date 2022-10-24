require 'rails_helper'

describe Reports::UniqueYearlyAuthsReport do
  subject { described_class.new }

  let(:issuer) { 'foo' }
  let(:year_month) { '201901' }
  let(:year) { '2019' }
  let(:app_id) { 'app_id' }

  it 'is empty' do
    expect(subject.perform(Time.zone.today)).to eq('[]')
  end

  it 'returns 1 unique despite the count for the user being 7' do
    ServiceProvider.create(issuer: issuer, friendly_name: issuer, app_id: app_id)
    MonthlySpAuthCount.create(
      issuer: 'foo', ial: 1, year_month: year_month, user_id: 2,
      auth_count: 7
    )
    result = [{ issuer: 'foo', app_id: app_id, year: year, total: 1 }].to_json

    expect(subject.perform(Time.zone.today)).to eq(result)
  end
end
