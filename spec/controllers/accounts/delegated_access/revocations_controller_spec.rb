require 'rails_helper'

RSpec.describe Accounts::DelegatedAccess::RevocationsController do
  let(:user) { create(:user, :fully_registered) }
  let(:mybenefits) do
    create(:service_provider, :delegation_service_provider, friendly_name: 'MyBenefits Assistant')
  end
  let(:other_sp) { create(:service_provider, :delegation_service_provider) }
  let(:housing) do
    create(
      :service_provider, :delegation_application,
      delegation_display_name: { en: 'Housing Assistance Records' }
    )
  end
  let(:retirement) { create(:service_provider, :delegation_application) }

  before do
    stub_analytics
    stub_sign_in(user)
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

  describe '#show' do
    it 'confirms a single application' do
      get :show, params: { service_provider_id: mybenefits.id, application_id: housing.id }

      expect(response).to render_template(:show)
      expect(assigns(:revocation).scope_name).to eq('application')
      expect(assigns(:applications)).to eq([housing])
    end

    it 'confirms everything for a service provider, and everything overall' do
      get :show, params: { service_provider_id: mybenefits.id }
      expect(assigns(:revocation).grants.size).to eq(2)

      get :show
      expect(assigns(:revocation).grants.size).to eq(3)
    end

    it 'goes back to the page when there is nothing to revoke' do
      live.update_all(revoked_at: Time.zone.now, revocation_reason: 'user_revoked')
      get :show, params: { service_provider_id: mybenefits.id }
      expect(response).to redirect_to(account_delegated_access_path)
    end

    it 'is not found for an unknown service provider' do
      get :show, params: { service_provider_id: 999_999 }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe '#destroy' do
    it 'revokes one application and tells the person' do
      expect do
        delete :destroy, params: { service_provider_id: mybenefits.id, application_id: housing.id }
      end.to change { user.events.where(event_type: 'delegation_revoked').count }.by(1)
        .and change { ActionMailer::Base.deliveries.count }.by(1)

      expect(response).to redirect_to(account_delegated_access_path)
      expect(live.count).to eq(2)
      expect(live.where(service_provider_issuer: mybenefits.issuer).map(&:application))
        .to eq([retirement])
      expect(ActionMailer::Base.deliveries.last.subject).to eq(
        t('user_mailer.delegation_revoked.subject', sp_name: 'MyBenefits Assistant'),
      )
      expect(@analytics).to have_logged_event(
        :delegation_account_revoked,
        service_provider_issuer: mybenefits.issuer, applications: [housing.issuer],
        scope: 'application'
      )
    end

    it 'revokes everything for a service provider' do
      delete :destroy, params: { service_provider_id: mybenefits.id }

      expect(live.map(&:service_provider_issuer)).to eq([other_sp.issuer])
      expect(@analytics).to have_logged_event(
        :delegation_account_revoked, hash_including(scope: 'service_provider')
      )
    end

    it 'ends all delegated access with one email naming every application' do
      delete :destroy

      expect(live).to be_empty
      expect(ActionMailer::Base.deliveries.last.subject).to eq(
        t('user_mailer.delegation_revoked.subject_all'),
      )
      # A nil issuer is not logged at all: the event carries only the applications and scope.
      expect(@analytics).to have_logged_event(
        :delegation_account_revoked,
        applications: match_array([housing.issuer, retirement.issuer, housing.issuer]),
        scope: 'all',
      )
      expect(flash[:success]).to eq(t('account.delegated_access.revoked_flash', count: 3))
    end

    it 'does nothing noisy when there is nothing left to revoke' do
      live.update_all(revoked_at: Time.zone.now, revocation_reason: 'user_revoked')
      expect { delete :destroy }.not_to change { ActionMailer::Base.deliveries.count }
      expect(response).to redirect_to(account_delegated_access_path)
    end
  end
end
