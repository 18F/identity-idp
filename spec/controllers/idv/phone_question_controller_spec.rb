require 'rails_helper'

RSpec.describe Idv::PhoneQuestionController do
  include IdvHelper

  let(:user) { create(:user) }

  before do
    stub_sign_in(user)
    stub_analytics
    stub_attempts_tracker
    subject.user_session['idv/doc_auth'] = {}
    subject.idv_session.idv_consent_given = true
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end

    it 'includes outage before_action' do
      expect(subject).to have_actions(
        :before,
        :check_for_mail_only_outage,
      )
    end

    it 'checks that agreement step is complete' do
      expect(subject).to have_actions(
        :before,
        :confirm_agreement_step_complete,
      )
    end

    it 'checks that hybrid_handoff is needed' do
      expect(subject).to have_actions(
        :before,
        :confirm_hybrid_handoff_needed,
      )
    end
  end

  describe '#show' do
    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    context 'agreement step is not complete' do
      before do
        subject.idv_session.idv_consent_given = nil
      end

      it 'redirects to idv_agreement_url' do
        get :show

        expect(response).to redirect_to(idv_agreement_url)
      end
    end

    context 'hybrid_handoff already visited' do
      it 'redirects to document_capture in standard flow' do
        subject.idv_session.flow_path = 'standard'

        get :show

        expect(response).to redirect_to(idv_hybrid_handoff_url)
      end

      it 'redirects to link_sent in hybrid flow' do
        subject.idv_session.flow_path = 'hybrid'

        get :show

        expect(response).to redirect_to(idv_hybrid_handoff_url)
      end
    end

    context 'hybrid flow is not available' do
      before do
        allow(FeatureManagement).to receive(:idv_allow_hybrid_flow?).and_return(false)
      end

      it 'redirects the user straight to document capture' do
        get :show
        expect(response).to redirect_to(idv_hybrid_handoff_url)
      end
    end
  end
end
