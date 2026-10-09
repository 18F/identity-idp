require 'rails_helper'

RSpec.describe AccountDelegationApproval do
  let(:user) { create(:user, :fully_registered) }
  let(:mybenefits) { create(:service_provider, :delegation_service_provider) }
  let(:housing) { create(:service_provider, :delegation_application) }
  let(:retirement) { create(:service_provider, :delegation_application) }

  before { allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true) }

  it 'records one remembered approval per application, from the account page' do
    grants = described_class.new(
      user:, service_provider: mybenefits, applications: [housing, retirement],
    ).call

    expect(grants.map(&:application)).to eq([housing, retirement])
    grants.each do |grant|
      expect(grant.source).to eq('account_page')
      expect(grant.remember_until).to be_within(1.minute).of(TokenExchangeGrant::MAX_REMEMBER.from_now)
      expect(grant.rails_session_id).to be_nil
      expect(grant.service_provider_issuer).to eq(mybenefits.issuer)
    end
  end

  it 'supersedes an earlier approval for the same application so one live row remains' do
    earlier = TokenExchangeGrant.approve!(
      user:, service_provider: mybenefits, application: housing,
      source: 'consent_screen', remember: false, rails_session_id: 'abc'
    )

    described_class.new(user:, service_provider: mybenefits, applications: [housing]).call

    expect(earlier.reload.revocation_reason).to eq('superseded_by_new_consent')
    expect(
      TokenExchangeGrant.live.where(user:, application: housing).count,
    ).to eq(1)
  end
end
