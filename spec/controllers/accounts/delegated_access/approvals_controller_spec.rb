require 'rails_helper'

RSpec.describe Accounts::DelegatedAccess::ApprovalsController do
  let(:user) { create(:user, :fully_registered) }
  let(:mybenefits) do
    create(:service_provider, :delegation_service_provider, friendly_name: 'MyBenefits Assistant')
  end
  let!(:housing) do
    create(
      :service_provider, :delegation_application,
      delegation_display_name: { en: 'Housing Assistance Records' }
    )
  end
  let!(:retirement) do
    create(
      :service_provider, :delegation_application,
      delegation_display_name: { en: 'Retirement Benefits Portal' }
    )
  end
  let!(:unrelated) { create(:service_provider) }

  before do
    stub_analytics
    stub_sign_in(user)
    allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
  end

  def live_grants
    TokenExchangeGrant.live.where(user:, service_provider_issuer: mybenefits.issuer)
  end

  describe '#new' do
    it 'shows the selected applications for confirmation' do
      get :new, params: { service_provider_id: mybenefits.id, application_ids: [housing.id] }

      expect(response).to render_template(:new)
      expect(assigns(:presenter).applications).to eq([housing])
    end

    it 'drops anything that is not an application accepting this service provider' do
      get :new, params: {
        service_provider_id: mybenefits.id, application_ids: [housing.id, unrelated.id, 999_999]
      }

      expect(assigns(:presenter).applications).to eq([housing])
    end

    it 'drops an application the person already has a remembered approval for' do
      TokenExchangeGrant.approve!(
        user:, service_provider: mybenefits, application: housing,
        source: 'account_page', remember: true
      )

      get :new, params: {
        service_provider_id: mybenefits.id, application_ids: [housing.id, retirement.id]
      }

      expect(assigns(:presenter).applications).to eq([retirement])
    end

    it 'returns to the page with a notice when nothing valid was selected' do
      get :new, params: { service_provider_id: mybenefits.id, application_ids: [unrelated.id] }

      expect(response).to redirect_to(
        account_delegated_access_path(anchor: "delegated-access-#{mybenefits.id}"),
      )
      expect(flash[:info]).to eq(t('account.delegated_access.nothing_selected'))
    end

    it 'is not found for a service provider that is not approved for delegation' do
      get :new, params: { service_provider_id: unrelated.id, application_ids: [housing.id] }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe '#create' do
    context 'with an application enrolled in the Attempts API' do
      before do
        allow(IdentityConfig.store).to receive_messages(
          attempts_api_enabled: true,
          token_exchange_attempts_delivery_enabled: true,
          allowed_attempts_providers: [{ 'issuer' => housing.issuer, 'keys' => [] }],
        )
      end

      it 'tells the agency of the approval, attributed to the agency identifier' do
        post :create, params: { service_provider_id: mybenefits.id, application_ids: [housing.id] }

        jwes = AttemptsApi::RedisClient.new.read_events(issuer: housing.issuer).values
        events = jwes.map do |jwe|
          AttemptsApi::AttemptEvent.from_jwe(jwe, saml_test_sp_private_key)
        end
        expect(events.map(&:event_type)).to eq(['delegated-access-consented'])
        expect(events.first.event_metadata).to include(
          user_uuid: AgencyIdentity.find_by(user:, agency: housing.agency).uuid,
          delegation_id: live_grants.first.delegation_id,
          actor_issuer: mybenefits.issuer,
          application: housing.issuer,
          remembered: false,
          source: 'account_page',
        )
        expect(ServiceProviderIdentity.where(user:, service_provider: housing.issuer)).to be_empty
      end
    end

    it 'records remembered approvals, the account event and an email, and logs analytics' do
      expect do
        post :create, params: {
          service_provider_id: mybenefits.id, application_ids: [housing.id, retirement.id]
        }
      end.to change { user.events.where(event_type: 'delegation_approved').count }.by(1)
        .and change { ActionMailer::Base.deliveries.count }.by(1)

      expect(response).to redirect_to(
        account_delegated_access_path(anchor: "delegated-access-#{mybenefits.id}"),
      )
      expect(live_grants.map(&:application)).to contain_exactly(housing, retirement)
      expect(live_grants.pluck(:source).uniq).to eq(['account_page'])
      expect(live_grants.pluck(:remember_until)).to all(be_within(1.minute).of(1.year.from_now))

      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to eq(
        t('user_mailer.delegation_approved.subject', sp_name: 'MyBenefits Assistant'),
      )
      expect(mail.html_part.body.to_s).to include('Housing Assistance Records')
      expect(mail.html_part.body.to_s).to include('Retirement Benefits Portal')

      expect(@analytics).to have_logged_event(
        :delegation_account_approved,
        service_provider_issuer: mybenefits.issuer,
        applications: [housing.issuer, retirement.issuer],
      )
      expect(flash[:success]).to eq(
        t('account.delegated_access.approved_flash', count: 2, sp: 'MyBenefits Assistant'),
      )
    end

    it 'records nothing when the selection is empty' do
      expect do
        post :create, params: { service_provider_id: mybenefits.id, application_ids: [] }
      end.not_to change { TokenExchangeGrant.count }
      expect(response).to redirect_to(
        account_delegated_access_path(anchor: "delegated-access-#{mybenefits.id}"),
      )
    end
  end
end
