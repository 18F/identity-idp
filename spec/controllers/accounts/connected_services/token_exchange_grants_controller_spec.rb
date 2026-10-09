require 'rails_helper'

RSpec.describe Accounts::ConnectedServices::TokenExchangeGrantsController do
  let(:user) { create(:user, :fully_registered) }
  let(:service_provider) do
    create(
      :service_provider, :delegation_service_provider,
      issuer: 'urn:gov:gsa:openidconnect:sp:mybenefits'
    )
  end
  let(:application) do
    create(
      :service_provider, :delegation_application,
      issuer: 'urn:gov:gsa:openidconnect:sp:housing_records',
      allowed_delegation_service_providers: [service_provider.issuer]
    )
  end
  let!(:service_provider_identity) do
    create(:service_provider_identity, user:, service_provider: service_provider.issuer)
  end
  let!(:application_identity) do
    create(:service_provider_identity, user:, service_provider: application.issuer)
  end

  before do
    stub_analytics
    stub_sign_in(user)
    allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
  end

  def toggle(enabled:, application_issuer: application.issuer, identity_id: nil)
    patch :update, params: {
      identity_id: identity_id || service_provider_identity.id,
      application_issuer:,
      enabled: enabled ? '1' : '0',
    }
  end

  def grant
    TokenExchangeGrant.live_for(
      user:, service_provider_issuer: service_provider.issuer, application:,
    )
  end

  describe '#update' do
    it 'approves an application from the account page and redirects back to the card' do
      toggle(enabled: true)

      expect(response).to redirect_to(
        account_connected_services_path(anchor: "connected-app-#{service_provider_identity.id}"),
      )
      expect(grant).to be_present
      expect(grant.source).to eq('account_page')
      expect(grant.remember_until).to be_within(1.minute).of(1.year.from_now)
      expect(@analytics).to have_logged_event(
        :delegation_grant_toggled,
        issuer: service_provider.issuer, application_issuer: application.issuer, enabled: true,
      )
    end

    it 'revokes an approval when toggled off, keeping the row for the record' do
      TokenExchangeGrant.approve!(
        user:, service_provider:, application:, source: 'account_page', remember: true,
      )

      toggle(enabled: false)

      expect(grant).to be_nil
      expect(TokenExchangeGrant.where(user:, application:).first.revocation_reason)
        .to eq('user_revoked')
    end

    it 'refuses an application that does not accept this service provider' do
      application.update!(allowed_delegation_service_providers: ['urn:someone-else'])
      toggle(enabled: true)

      expect(response).to have_http_status(:not_found)
      expect(grant).to be_nil
    end

    it 'refuses an application the user has not connected to' do
      application_identity.destroy!
      toggle(enabled: true)

      expect(response).to have_http_status(:not_found)
    end

    it 'refuses when the connected app is not a service provider approved for delegation' do
      service_provider.update!(token_exchange_enabled_sp: false)
      toggle(enabled: true)

      expect(response).to have_http_status(:not_found)
    end

    it 'refuses approving the service provider at itself' do
      service_provider.update!(
        delegation_application: true,
        allowed_delegation_service_providers: [service_provider.issuer],
      )
      toggle(enabled: true, application_issuer: service_provider.issuer)

      expect(response).to have_http_status(:not_found)
    end

    it "refuses another user's connected app" do
      other = create(
        :service_provider_identity, user: create(:user), service_provider: service_provider.issuer
      )
      toggle(enabled: true, identity_id: other.id)

      expect(response).to have_http_status(:not_found)
    end

    it 'refuses an unknown application' do
      toggle(enabled: true, application_issuer: 'urn:unknown')

      expect(response).to have_http_status(:not_found)
    end
  end
end
