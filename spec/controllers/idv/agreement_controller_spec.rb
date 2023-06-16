require 'rails_helper'

RSpec.describe Idv::AgreementController do
  include IdvHelper

  let(:user) { create(:user) }

  let(:feature_flag_enabled) { true }

  before do
    allow(IdentityConfig.store).to receive(:doc_auth_agreement_controller_enabled).
      and_return(feature_flag_enabled)
    stub_sign_in(user)
    stub_analytics
    subject.user_session['idv/doc_auth'] = { 'Idv::Steps::WelcomeStep' => true }
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
        :check_for_outage,
      )
    end
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: doc auth agreement visited' }
    let(:analytics_args) do
      { step: 'agreement',
        analytics_id: 'Doc Auth',
        irs_reproofing: false }
    end

    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    it 'sends analytics_visited event' do
      get :show

      expect(@analytics).to have_logged_event(analytics_name, analytics_args)
    end

    it 'updates DocAuthLog agreement_view_count' do
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { get :show }.to(
        change { doc_auth_log.reload.agreement_view_count }.from(0).to(1),
      )
    end

    context 'welcome step is not complete' do
      it 'redirects to idv_doc_auth_url' do
        subject.user_session['idv/doc_auth']['Idv::Steps::WelcomeStep'] = nil

        get :show

        expect(response).to redirect_to(idv_doc_auth_url)
      end
    end

    context 'agreement already visited' do
      it 'redirects to hybrid_handoff' do
        allow(subject.idv_session).to receive(:idv_consent_given).and_return(true)

        get :show

        expect(response).to redirect_to(idv_hybrid_handoff_url)
      end
    end
  end

  describe '#update' do
    let(:analytics_name) { 'IdV: doc auth agreement submitted' }

    let(:analytics_args) do
      { success: true,
        errors: {},
        step: 'agreement',
        analytics_id: 'Doc Auth',
        irs_reproofing: false }
    end

    it 'sends analytics_submitted event with consent given' do
      put :update, params: { doc_auth: { ial2_consent_given: 1 } }

      expect(@analytics).to have_logged_event(analytics_name, analytics_args)
    end
  end
end
