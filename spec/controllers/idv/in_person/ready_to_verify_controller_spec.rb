require 'rails_helper'

describe Idv::InPerson::ReadyToVerifyController do
  let(:user) { create(:user) }
  let(:in_person_proofing_enabled) { false }

  before do
    stub_analytics
    stub_sign_in(user)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
      and_return(in_person_proofing_enabled)
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(:before, :confirm_two_factor_authenticated)
    end
  end

  describe '#show' do
    subject(:response) { get :show }

    it 'renders not found' do
      expect(response.status).to eq 404
    end

    context 'with in person proofing enabled' do
      let(:in_person_proofing_enabled) { true }

      it 'redirects to account page' do
        expect(response).to redirect_to account_url
      end

      context 'with enrollment' do
        let(:user) { create(:user, :with_pending_in_person_enrollment) }
        let(:profile) { create(:profile, :with_pii, user: user) }

        it 'renders show template' do
          expect(response).to render_template :show
        end

        it 'logs analytics' do
          response

          expect(@analytics).to have_logged_event('IdV: in person ready to verify visited')
        end
      end
    end
  end
end
