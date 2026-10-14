require 'rails_helper'

RSpec.describe TokenExchangeConsent do
  let(:user) { create(:user, :fully_registered) }
  let(:service_provider) { create(:service_provider, :delegation_service_provider) }
  let(:housing) { create(:service_provider, :delegation_application) }
  let(:retirement) { create(:service_provider, :delegation_application) }

  before { allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true) }

  def consent(remember:, applications: [housing, retirement])
    described_class.new(
      user:, service_provider:, applications:, remember:,
      rails_session_id: 'session-1', proofed_in_session: true
    ).call
  end

  def live(application)
    TokenExchangeGrant.live_for(
      user:, service_provider_issuer: service_provider.issuer, application:,
    )
  end

  it 'approves every requested application for this authorization only when not remembered' do
    result = consent(remember: false)

    expect(result.approved.map(&:application)).to contain_exactly(housing, retirement)
    expect(result.kept).to be_empty
    result.approved.each do |grant|
      expect(grant.source).to eq('consent_screen')
      expect(grant.remember_until).to be_nil
      expect(grant.rails_session_id).to eq('session-1')
      expect(grant.proofed_in_session).to eq(true)
      expect(grant.delegation_id).to start_with('dlg_')
    end
  end

  it 'remembers the approvals for the maximum period when asked' do
    result = consent(remember: true)

    result.approved.each do |grant|
      expect(grant.remember_until).to be_within(1.minute).of(TokenExchangeGrant::MAX_REMEMBER.from_now)
      expect(grant.rails_session_id).to be_nil
    end
  end

  it 'leaves an existing remembered, current approval untouched whatever the remember choice' do
    earlier = TokenExchangeGrant.approve!(
      user:, service_provider:, application: housing, source: 'account_page', remember: true,
    )

    result = consent(remember: false)

    expect(result.kept).to eq([earlier])
    expect(result.approved.map(&:application)).to eq([retirement])
    expect(live(housing)).to eq(earlier)
    expect(earlier.reload.remember_until).to be_present
  end

  it 're-records an approval made stale by a material content change' do
    earlier = TokenExchangeGrant.approve!(
      user:, service_provider:, application: housing, source: 'consent_screen', remember: true,
    )
    housing.update!(consent_content_version: 2, consent_material_version: 2)

    result = consent(remember: true, applications: [housing])

    expect(result.kept).to be_empty
    expect(earlier.reload.revoked_at).to be_present
    expect(earlier.revocation_reason).to eq('superseded_by_new_consent')
    expect(live(housing).application_content_version).to eq(2)
  end

  it 're-records a single-authorization approval from an earlier sign-in' do
    TokenExchangeGrant.approve!(
      user:, service_provider:, application: housing, source: 'consent_screen', remember: false,
      rails_session_id: 'session-0'
    )

    result = consent(remember: false, applications: [housing])

    expect(result.approved.size).to eq(1)
    expect(live(housing).rails_session_id).to eq('session-1')
    expect(TokenExchangeGrant.where(user:, application: housing).count).to eq(2)
  end
end
