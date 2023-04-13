require 'rails_helper'

describe Idv::HybridMobile::EntryController do
  include IdvHelper

  describe '#show' do
    let(:feature_flag_enabled) { true }

    let(:user) { create(:user) }

    let!(:document_capture_session) do
      DocumentCaptureSession.create!(
        user: user,
        requested_at: Time.zone.now,
      )
    end

    let(:session_uuid) { document_capture_session.uuid }

    before do
      stub_analytics
      stub_attempts_tracker

      allow(IdentityConfig.store).to receive(:doc_auth_hybrid_mobile_controllers_enabled).
        and_return(feature_flag_enabled)
    end

    context 'feature flag disabled' do
      let(:feature_flag_enabled) { false }

      it '404s' do
        get :show
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with no session' do
      it 'redirects to the root url' do
        get :show

        expect(@irs_attempts_api_tracker.events).to have_key(:idv_phone_upload_link_used)

        expect(response).to redirect_to root_url
      end
    end

    context 'with a bad session' do
      it 'redirects to the root url' do
        get :show, params: { 'document-capture-session': 'foo' }

        expect(@irs_attempts_api_tracker.events).to have_key(:idv_phone_upload_link_used)

        expect(response).to redirect_to root_url
      end
    end

    context 'with an expired token' do
      it 'redirects to the root url' do
        travel_to(Time.zone.now + 1.day) do
          get :show, params: { 'document-capture-session': session_uuid }
        end

        expect(@irs_attempts_api_tracker.events).to have_key(:idv_phone_upload_link_used)

        expect(response).to redirect_to root_url
      end
    end

    context 'with a good session uuid' do
      it 'redirects to the first step' do
        get :show, params: { 'document-capture-session': session_uuid }

        expect(@irs_attempts_api_tracker.events).to have_key(:idv_phone_upload_link_used)

        expect(response).to redirect_to idv_hybrid_mobile_capture_doc_url
      end

      context 'but we already had a session' do
        let!(:different_document_capture_session) do
          DocumentCaptureSession.create!(
            user: user,
            requested_at: Time.zone.now,
          )
        end

        before do
          allow(controller).to receive(:session).and_return(
            {
              doc_capture_user_id: user.id,
              document_capture_session_uuid: different_document_capture_session.uuid,
            },
          )
          get :show, params: { 'document-capture-session': session_uuid }
        end

        it 'assumes new document capture session' do
          expect(controller.session).to include(document_capture_session_uuid: session_uuid)
        end

        it 'redirects to the document capture screen' do
          expect(response).to redirect_to idv_hybrid_mobile_capture_doc_url
        end
      end
    end

    context 'with a user id in session and no session uuid' do
      let(:user) { create(:user) }

      it 'redirects to the first step' do
        session[:doc_capture_user_id] = user.id

        get :show

        expect(@irs_attempts_api_tracker.events).to have_key(:idv_phone_upload_link_used)

        expect(response).to redirect_to idv_hybrid_mobile_capture_doc_url
      end
    end
  end
end
