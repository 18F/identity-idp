# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Idv::ProofingAgentExpiredController do
  let(:user) { create(:user) }

  before do
    stub_sign_in(user)
    stub_analytics
  end

  describe 'before_actions' do
    it 'includes confirm_two_factor_authenticated and confirm_proofing_agent_session_expired' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_proofing_agent_session_expired,
      )
    end
  end

  context 'when the session is not expired' do
    before do
      allow(user).to receive(:agent_proofing_expired?).and_return(false)
    end

    it 'redirects #show to account_path' do
      get :show
      expect(response).to redirect_to account_path
    end

    it 'redirects #update to account_path' do
      post :update
      expect(response).to redirect_to account_path
    end
  end

  context 'when the session is expired' do
    before do
      allow(user).to receive(:agent_proofing_expired?).and_return(true)
    end

    describe '#show' do
      it 'renders the show template' do
        get :show

        expect(response).to render_template :show
      end

      it 'sends idv_proofing_agent_expired_visited event' do
        get :show

        expect(@analytics).to have_logged_event(:idv_proofing_agent_expired_visited)
      end
    end

    describe '#update' do
      let!(:expired_session) do
        create(:document_capture_session, user: user, doc_auth_vendor: 'proofing_agent')
      end
      let!(:other_session) do
        create(:document_capture_session, user: user, doc_auth_vendor: 'lexisnexis')
      end

      it 'clears expired proofing agent sessions and redirects to idv_welcome_path' do
        post :update

        expect(response).to redirect_to idv_welcome_path
        expect(
          user.document_capture_sessions.where(doc_auth_vendor: 'proofing_agent').count,
        ).to eq(0)
        expect(user.document_capture_sessions.where(doc_auth_vendor: 'lexisnexis').count).to eq(1)
      end

      it 'sends idv_proofing_agent_expired_continued event' do
        post :update

        expect(@analytics).to have_logged_event(:idv_proofing_agent_expired_continued)
      end
    end
  end
end
