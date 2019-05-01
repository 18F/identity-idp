require 'rails_helper'

describe DeletedAccountsReport do
  let(:service_provider) { 'urn:gov:gsa:openidconnect:sp:sinatra' }
  let(:days_ago) { 30 }
  describe '#call' do
    it 'prints the report with zero records when no users or identities' do
      rows = DeletedAccountsReport.call(service_provider, days_ago)

      expect(rows.count).to eq(0)
    end

    it 'prints the report with zero records when no users are deleted' do
      user = create(:user)
      create(:identity, service_provider: service_provider, user: user,
                        last_authenticated_at: Time.zone.now)
      rows = DeletedAccountsReport.call(service_provider, days_ago)

      expect(User.count).to eq(1)
      expect(Identity.count).to eq(1)
      expect(rows.count).to eq(0)
    end

    it 'prints the report with one record' do
      user = create(:user)
      create(:identity, service_provider: service_provider, user: user,
                        last_authenticated_at: Time.zone.now)
      user.destroy!
      rows = DeletedAccountsReport.call(service_provider, days_ago)

      expect(User.count).to eq(0)
      expect(Identity.count).to eq(1)
      expect(rows.count).to eq(1)
    end

    it 'prints the report with zero records when the last auth date is beyond days ago' do
      user = create(:user)
      create(:identity, service_provider: service_provider, user: user,
                        last_authenticated_at: days_ago + 1)
      user.destroy!
      rows = DeletedAccountsReport.call(service_provider, days_ago)

      expect(User.count).to eq(0)
      expect(Identity.count).to eq(1)
      expect(rows.count).to eq(0)
    end

    it 'prints the report with zero records when it is not the correct sp' do
      user = create(:user)
      create(:identity, service_provider: 'foo', user: user, last_authenticated_at: Time.zone.now)
      user.destroy!
      rows = DeletedAccountsReport.call(service_provider, days_ago)

      expect(User.count).to eq(0)
      expect(Identity.count).to eq(1)
      expect(rows.count).to eq(0)
    end
  end
end
