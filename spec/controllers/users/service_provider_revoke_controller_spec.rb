require 'rails_helper'

RSpec.describe Users::ServiceProviderRevokeController do
  describe 'before_actions' do
    it 'includes appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end
  end

  let(:service_provider) { create(:service_provider) }

  let(:user) { create(:user) }
  let(:sp_id) { service_provider.id }

  before do
    stub_sign_in(user)

    @identity = IdentityLinker.new(user, service_provider).link_identity
  end

  describe '#show' do
    subject { get :show, params: { sp_id: sp_id } }

    it 'renders' do
      subject
      expect(response).to render_template(:show)
    end

    it 'logs an analytics event for visiting' do
      stub_analytics
      expect(@analytics).to receive(:track_event).
        with('SP Revoke Consent: Visited', issuer: service_provider.issuer)

      subject
    end

    context 'when the sp_id is not valid' do
      let(:sp_id) { -1000 }

      it 'does not error, just redirects to the account page' do
        subject
        expect(response).to redirect_to(account_connected_accounts_path)
      end
    end

    context 'when the sp_id links to a valid SP but it has not been linked' do
      let(:sp_id) { create(:service_provider).id }

      it 'does not error, just redirects to the account page' do
        subject
        expect(response).to redirect_to(account_connected_accounts_path)
      end
    end
  end

  describe '#destroy' do
    let(:now) { Time.zone.now }
    subject { delete :destroy, params: { sp_id: sp_id } }

    it 'marks the identity as deleted and redirects' do
      expect do
        freeze_time do
          travel_to(now)
          subject
        end
      end.to change { @identity.reload.deleted_at&.to_i }.
      from(nil).to(now.to_i)

      expect(response).to redirect_to(account_connected_accounts_path)
    end

    it 'logs an analytics event for revoking' do
      stub_analytics
      expect(@analytics).to receive(:track_event).
        with('SP Revoke Consent: Revoked', issuer: service_provider.issuer)

      subject
    end

    context 'when the sp_id is not valid' do
      let(:sp_id) { -1000 }

      it 'does not error, just redirects to the account page' do
        subject
        expect(response).to redirect_to(account_connected_accounts_path)
      end
    end

    context 'when the sp_id links to a valid SP but it has not been linked' do
      let(:sp_id) { create(:service_provider).id }

      it 'does not error, just redirects to the account page' do
        subject
        expect(response).to redirect_to(account_connected_accounts_path)
      end
    end
  end
end
