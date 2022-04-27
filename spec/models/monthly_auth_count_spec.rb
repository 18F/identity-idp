require 'rails_helper'

describe MonthlySpAuthCount do
  let(:user_id) { 1 }
  let(:issuer) { 'foo' }
  let(:service_provider) { build(:service_provider, issuer: issuer) }
  let(:ial) { 1 }

  describe '.increment' do
    it 'sets the monthly count to 1' do
      year_month = current_year_month
      MonthlySpAuthCount.increment(user_id: user_id, service_provider: service_provider, ial: ial)

      monthly_auth_count = MonthlySpAuthCount.first
      expect(monthly_auth_count.user_id).to eq(user_id)
      expect(monthly_auth_count.issuer).to eq(issuer)
      expect(monthly_auth_count.year_month).to eq(year_month)
      expect(monthly_auth_count.auth_count).to eq(1)
    end

    it 'updates the monthly count to 2' do
      year_month = current_year_month
      MonthlySpAuthCount.increment(user_id: user_id, service_provider: service_provider, ial: ial)
      MonthlySpAuthCount.increment(user_id: user_id, service_provider: service_provider, ial: ial)

      monthly_auth_count = MonthlySpAuthCount.first
      expect(monthly_auth_count.user_id).to eq(user_id)
      expect(monthly_auth_count.issuer).to eq(issuer)
      expect(monthly_auth_count.year_month).to eq(year_month)
      expect(monthly_auth_count.auth_count).to eq(2)
    end

    it 'updates the monthly count to 3' do
      year_month = current_year_month
      MonthlySpAuthCount.increment(user_id: user_id, service_provider: service_provider, ial: ial)
      MonthlySpAuthCount.increment(user_id: user_id, service_provider: service_provider, ial: ial)
      MonthlySpAuthCount.increment(user_id: user_id, service_provider: service_provider, ial: ial)

      monthly_auth_count = MonthlySpAuthCount.first
      expect(monthly_auth_count.user_id).to eq(user_id)
      expect(monthly_auth_count.issuer).to eq(issuer)
      expect(monthly_auth_count.year_month).to eq(year_month)
      expect(monthly_auth_count.auth_count).to eq(3)
    end
  end

  def current_year_month
    Time.zone.today.strftime('%Y%m')
  end
end
