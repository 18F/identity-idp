require 'rails_helper'

RSpec.describe AccountDelegationRevocation do
  let(:user) { create(:user, :fully_registered) }
  let(:mybenefits) { create(:service_provider, :delegation_service_provider) }
  let(:other_sp) { create(:service_provider, :delegation_service_provider) }
  let(:housing) { create(:service_provider, :delegation_application) }
  let(:retirement) { create(:service_provider, :delegation_application) }

  before do
    allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
    [[mybenefits, housing], [mybenefits, retirement], [other_sp, housing]].each do |sp, app|
      TokenExchangeGrant.approve!(
        user:, service_provider: sp, application: app, source: 'account_page', remember: true,
      )
    end
  end

  def live
    TokenExchangeGrant.live.where(user:)
  end

  it 'revokes one application of one service provider' do
    revocation = described_class.new(user:, service_provider: mybenefits, application: housing)

    expect(revocation.scope_name).to eq('application')
    revoked = revocation.call

    expect(revoked.size).to eq(1)
    expect(revoked.first.revocation_reason).to eq('user_revoked')
    expect(live.count).to eq(2)
    expect(live.where(service_provider_issuer: mybenefits.issuer).map(&:application))
      .to eq([retirement])
  end

  it 'revokes everything for one service provider' do
    revocation = described_class.new(user:, service_provider: mybenefits)

    expect(revocation.scope_name).to eq('service_provider')
    expect(revocation.call.size).to eq(2)
    expect(live.map(&:service_provider_issuer)).to eq([other_sp.issuer])
  end

  it 'revokes every approval the person has given' do
    revocation = described_class.new(user:)

    expect(revocation.scope_name).to eq('all')
    expect(revocation.call.size).to eq(3)
    expect(live).to be_empty
    expect(TokenExchangeGrant.where(user:).count).to eq(3)
  end

  it 'does nothing for another person or an unknown application' do
    stranger = create(:user, :fully_registered)
    expect(described_class.new(user: stranger).call).to be_empty
    expect(
      described_class.new(
        user:, service_provider: mybenefits, application: create(:service_provider),
      ).call,
    ).to be_empty
    expect(live.count).to eq(3)
  end
end
