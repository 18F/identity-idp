require 'rails_helper'

RSpec.describe BannedUserResolver do
  context 'the user is not banned' do
    it 'returns false' do
      user = create(:user)
      sp = create(:service_provider)

      expect(described_class.new(user).banned_for_sp?(issuer: sp.issuer)).to eq(false)
    end
  end

  context 'the user is banned for a single SP' do
    it 'returns true for the banned SP' do
      user = create(:user)
      sp = create(:service_provider)

      SignInRestriction.create(user: user, service_provider: sp.issuer)

      expect(described_class.new(user).banned_for_sp?(issuer: sp.issuer)).to eq(true)
    end

    it 'returns false for the not banned SP' do
      user = create(:user)
      sp = create(:service_provider)
      banned_sp = create(:service_provider)

      SignInRestriction.create(user: user, service_provider: banned_sp.issuer)

      expect(described_class.new(user).banned_for_sp?(issuer: sp.issuer)).to eq(false)
    end
  end

  context 'the user is banned for all SPs' do
    it 'returns true for all SPs' do
      user = create(:user)
      sp1 = create(:service_provider)
      sp2 = create(:service_provider)

      SignInRestriction.create(user: user, service_provider: nil)

      expect(described_class.new(user).banned_for_sp?(issuer: sp1.issuer)).to eq(true)
      expect(described_class.new(user).banned_for_sp?(issuer: sp2.issuer)).to eq(true)
      expect(described_class.new(user).banned_for_sp?(issuer: nil)).to eq(true)
    end
  end
end
