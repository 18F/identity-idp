require 'rails_helper'

RSpec.describe Reports::TotalMonthlyAuthsReport do
  subject { Reports::TotalMonthlyAuthsReport.new }

  let(:app_id) { 'app_id' }
  let(:sp) { create(:service_provider, :active, app_id:) }
  let(:issuer) { sp.issuer }
  let(:user1) { create(:user) }
  let(:user2) { create(:user) }
  let(:year_month) { '201901' }

  it 'is empty' do
    expect(subject.perform(Time.zone.today)).to eq('[]')
  end

  it 'returns the total monthly auths' do
    [
      { user_id: user1.id, count: 7 },
      { user_id: user2.id, count: 3 },
    ].each do |config|
      config[:count].times do
        create(
          :sp_return_log,
          user_id: config[:user_id],
          issuer:,
          ial: 1,
          billable: true,
          returned_at: Date.new(2019, 1, 15).to_date,
        )
      end
    end

    result = [{ issuer:, ial: 1, year_month:, total: 10, app_id: }].to_json

    expect(subject.perform(Time.zone.today)).to eq(result)
  end
end
