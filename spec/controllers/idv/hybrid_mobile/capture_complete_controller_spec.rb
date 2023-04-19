require 'rails_helper'

describe Idv::HybridMobile::CaptureCompleteController do
  include IdvHelper

  let(:user) { create(:user) }
  let(:service_provider) do
    create(
      :service_provider,
      issuer: 'http://sp.example.com',
      app_id: '123',
    )
  end

  before do
    stub_sign_in(user)
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end

    it 'checks that feature flag is enabled' do
      expect(subject).to have_actions(
        :before,
        :render_404_if_hybrid_mobile_controllers_disabled,
      )
    end
  end

  context 'when doc_auth_hybrid_mobile_controllers_enabled' do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_hybrid_mobile_controllers_enabled).
        and_return(true)
      stub_analytics
      allow(@analytics).to receive(:track_event)
    end

    describe '#show' do
      let(:analytics_name) { 'IdV: doc auth capture_complete visited' }
      let(:analytics_args) do
        {
          analytics_id: 'Doc Auth',
          flow_path: 'hybrid',
          irs_reproofing: false,
          step: 'capture_complete',
        }
      end

      it 'renders the show template' do
        get :show

        expect(response).to render_template :show
      end

      it 'sends analytics_visited event' do
        get :show

        expect(@analytics).to have_received(:track_event).with(analytics_name, analytics_args)
      end

      it 'updates DocAuthLog capture_complete_view_count' do
        doc_auth_log = DocAuthLog.create(user_id: user.id)

        expect { get :show }.to(
          change { doc_auth_log.reload.capture_complete_view_count }.from(0).to(1),
        )
      end
    end
  end
end
