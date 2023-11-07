require 'rails_helper'

RSpec.describe Reports::TotalMonthlyAuthsReport do
  subject { described_class.new }

  let(:issuer) { 'foo' }
  let(:app_id) { 'app_id' }
  let(:year_month) { '201901' }

  it 'is empty' do
    expect(subject.perform(Time.zone.today)).to eq('[]')
  end

  it 'returns the total monthly auths' do
    ServiceProvider.create(issuer:, friendly_name: issuer, app_id:)
    [
      { user_id: 2, count: 7 },
      { user_id: 3, count: 3 },
    ].each do |config|
      config[:count].times do
        create(
          :sp_return_log,
          user_id: config[:user_id],
          issuer:,
          ial: 1,
          billable: true,
          returned_at: Date.new(2019, 1, 15).to_date,
          requested_at: Date.new(2019, 1, 15).to_date,
        )
      end
    end

    result = [{ issuer: 'foo', ial: 1, year_month: '201901', total: 10, app_id: }].to_json

    expect(subject.perform(Time.zone.today)).to eq(result)
  end
end
