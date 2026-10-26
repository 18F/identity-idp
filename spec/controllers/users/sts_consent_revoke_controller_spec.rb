require 'rails_helper'

RSpec.describe Users::StsConsentRevokeController do
  describe 'before_actions' do
    it 'includes appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end
  end

  let(:user) { create(:user) }
  let!(:consent) { create(:user_consent_sts, user:) }
  let(:id) { consent.id }

  before do
    allow(IdentityConfig.store).to receive(:sts_consent_expiration_in_days).and_return(365)
    stub_sign_in(user)
  end

  describe '#show' do
    subject { get :show, params: { id: } }

    it 'renders' do
      subject

      expect(response).to render_template(:show)
    end

    it 'logs an analytics event for visiting' do
      stub_analytics

      subject

      expect(@analytics).to have_logged_event(
        :sts_revoke_consent_visited,
        target_app: consent.target_app,
      )
    end

    context 'when the id is not valid' do
      let(:id) { -1000 }

      it 'does not error, just redirects to the connected services page' do
        subject

        expect(response).to redirect_to(account_connected_services_path)
      end
    end

    context 'when the consent belongs to another user' do
      let(:id) { create(:user_consent_sts).id }

      it 'does not error, just redirects to the connected services page' do
        subject

        expect(response).to redirect_to(account_connected_services_path)
      end
    end

    context 'when the consent is expired' do
      before { consent.update!(created_at: 366.days.ago) }

      it 'does not error, just redirects to the connected services page' do
        subject

        expect(response).to redirect_to(account_connected_services_path)
      end
    end
  end

  describe '#destroy' do
    subject { delete :destroy, params: { id: } }

    it 'deletes the consent and redirects' do
      expect { subject }.to change { UserConsentSts.count }.by(-1)

      expect(UserConsentSts.find_by(id: consent.id)).to be_nil
      expect(response).to redirect_to(account_connected_services_path)
    end

    it 'logs an analytics event for revoking' do
      stub_analytics

      subject

      expect(@analytics).to have_logged_event(
        :sts_revoke_consent_revoked,
        target_app: consent.target_app,
      )
    end

    context 'when the id is not valid' do
      let(:id) { -1000 }

      it 'does not error, just redirects to the connected services page' do
        expect { subject }.to_not change { UserConsentSts.count }

        expect(response).to redirect_to(account_connected_services_path)
      end
    end

    context 'when the consent belongs to another user' do
      let!(:other_consent) { create(:user_consent_sts) }
      let(:id) { other_consent.id }

      it 'does not delete the other user’s consent' do
        expect { subject }.to_not change { UserConsentSts.count }

        expect(response).to redirect_to(account_connected_services_path)
      end
    end
  end
end
