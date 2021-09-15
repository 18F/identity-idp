require 'rails_helper'

describe Idv::SessionsController do
  let(:user) { build(:user) }

  before do
    stub_sign_in(user)
    stub_analytics
  end

  describe '#destroy' do
    let(:idv_session) { double }
    let(:flow_session) { {} }
    let(:pii) { { first_name: 'Jane' } }

    before do
      allow(idv_session).to receive(:clear)
      allow(subject).to receive(:idv_session).and_return(idv_session)
      controller.user_session['idv/doc_auth'] = flow_session
      controller.user_session[:decrypted_pii] = pii
    end

    it 'deletes idv session' do
      expect(idv_session).to receive(:clear)

      delete :destroy

      expect(controller.user_session['idv/doc_auth']).to be_blank
      expect(controller.user_session[:decrypted_pii]).to be_blank
    end

    it 'logs start over with step and location params' do
      delete :destroy, params: { step: 'first', location: 'get_help' }

      expect(@analytics).to have_logged_event(
        Analytics::IDV_START_OVER,
        step: 'first',
        location: 'get_help',
      )
    end

    it 'redirects to start of identity verificaton' do
      delete :destroy

      expect(response).to redirect_to(idv_url)
    end

    context 'pending profile' do
      let(:user) do
        create(
          :user,
          profiles: [create(:profile, deactivation_reason: :verification_pending)],
        )
      end

      it 'cancels verification attempt' do
        cancel = double
        expect(Idv::CancelVerificationAttempt).to receive(:new).and_return(cancel)
        expect(cancel).to receive(:call)

        delete :destroy, params: { step: 'gpo_verify', location: 'clear_and_start_over' }

        expect(@analytics).to have_logged_event(
          Analytics::IDV_START_OVER,
          step: 'gpo_verify',
          location: 'clear_and_start_over',
        )
      end
    end
  end
end
