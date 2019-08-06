require 'rails_helper'

describe MonthlyAuthCount do
  let(:user_id) { 1 }
  let(:issuer) { 'foo' }

  describe '.increment' do
    it 'sets the monthly count to 1' do
      year_month = current_year_month
      MonthlyAuthCount.increment(user_id, issuer)

      monthly_auth_count = MonthlyAuthCount.first
      expect(monthly_auth_count.user_id).to eq(user_id)
      expect(monthly_auth_count.issuer).to eq(issuer)
      expect(monthly_auth_count.year_month).to eq(year_month)
      expect(monthly_auth_count.auth_count).to eq(1)
    end

    it 'updates the monthly count to 2' do
      year_month = current_year_month
      MonthlyAuthCount.increment(user_id, issuer)
      MonthlyAuthCount.increment(user_id, issuer)

      monthly_auth_count = MonthlyAuthCount.first
      expect(monthly_auth_count.user_id).to eq(user_id)
      expect(monthly_auth_count.issuer).to eq(issuer)
      expect(monthly_auth_count.year_month).to eq(year_month)
      expect(monthly_auth_count.auth_count).to eq(2)
    end

    it 'updates the monthly count to 3' do
      year_month = current_year_month
      MonthlyAuthCount.increment(user_id, issuer)
      MonthlyAuthCount.increment(user_id, issuer)
      MonthlyAuthCount.increment(user_id, issuer)

      monthly_auth_count = MonthlyAuthCount.first
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
