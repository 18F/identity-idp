require 'rails_helper'

describe Idv::InPerson::ReadyToVerifyController do
  let(:user) { create(:user) }
  let(:in_person_proofing_enabled) { false }
  let(:enrollment) { nil }

  before do
    stub_analytics
    stub_sign_in(user)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
      and_return(in_person_proofing_enabled)
    allow(controller).to receive(:enrollment).and_return(enrollment)
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
        let(:profile) { create(:profile, :with_pii, user: user) }
        let(:enrollment) do
          InPersonEnrollment.new(
            user: user,
            profile: profile,
            enrollment_code: '2048702198804358',
            created_at: Time.zone.now,
          )
        end

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
