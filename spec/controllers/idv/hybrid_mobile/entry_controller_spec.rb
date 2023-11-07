require 'rails_helper'

RSpec.describe Idv::HybridMobile::EntryController do
  describe '#show' do
    let(:user) { create(:user) }

    let!(:document_capture_session) do
      DocumentCaptureSession.create!(
        user:,
        requested_at: Time.zone.now,
      )
    end

    let(:session_uuid) { document_capture_session.uuid }

    before do
      stub_analytics
      stub_attempts_tracker
    end

    context 'with no session' do
      before do
        get :show
      end
      it 'logs that phone upload link was used' do
        expect(@irs_attempts_api_tracker.events).to have_key(:idv_phone_upload_link_used)
      end
      it 'redirects to the root url' do
        expect(response).to redirect_to root_url
      end
    end

    context 'with a bad session' do
      before do
        get :show, params: { 'document-capture-session': 'foo' }
      end
      it 'logs that phone upload link was used' do
        expect(@irs_attempts_api_tracker.events).to have_key(:idv_phone_upload_link_used)
      end
      it 'logs an analytics event' do
        expect(@analytics).to have_logged_event(
          'Doc Auth',
          hash_including(
            success: false,
            errors: { session_uuid: ['invalid session'] },
          ),
        )
      end
      it 'redirects to the root url' do
        expect(response).to redirect_to root_url
      end
    end

    context 'with an expired token' do
      before do
        travel_to(Time.zone.now + 1.day) do
          get :show, params: { 'document-capture-session': session_uuid }
        end
      end

      it 'logs that phone upload link was used' do
        expect(@irs_attempts_api_tracker.events).to have_key(:idv_phone_upload_link_used)
      end

      it 'redirects to the root url' do
        expect(response).to redirect_to root_url
      end
    end

    context 'with a good session uuid' do
      let(:session) do
        {}
      end

      before do
        allow(controller).to receive(:session).and_return(session)
        get :show, params: { 'document-capture-session': session_uuid }
      end

      it 'logs that phone upload link was used' do
        expect(@irs_attempts_api_tracker.events).to have_key(:idv_phone_upload_link_used)
      end

      it 'redirects to the first step' do
        expect(response).to redirect_to idv_hybrid_mobile_document_capture_url
      end

      it 'logs an analytics event' do
        expect(@analytics).to have_logged_event(
          'Doc Auth',
          hash_including(
            success: true,
            doc_capture_user_id?: false,
          ),
        )
      end

      context 'but we already had a session' do
        let!(:different_document_capture_session) do
          DocumentCaptureSession.create!(
            user:,
            requested_at: Time.zone.now,
          )
        end

        let(:session) do
          {
            doc_capture_user_id: user.id,
            document_capture_session_uuid: different_document_capture_session.uuid,
          }
        end

        it 'assumes new document capture session' do
          expect(controller.session).to include(document_capture_session_uuid: session_uuid)
        end

        it 'logs an analytics event' do
          expect(@analytics).to have_logged_event(
            'Doc Auth',
            hash_including(
              success: true,
              doc_capture_user_id?: true,
            ),
          )
        end

        it 'redirects to the document capture screen' do
          expect(response).to redirect_to idv_hybrid_mobile_document_capture_url
        end
      end
    end

    context 'with a user id in session and no session uuid' do
      let(:user) { create(:user) }

      before do
        session[:doc_capture_user_id] = user.id
        get :show
      end

      it 'logs that phone upload link was used' do
        expect(@irs_attempts_api_tracker.events).to have_key(:idv_phone_upload_link_used)
      end

      it 'redirects to the first step' do
        expect(response).to redirect_to idv_hybrid_mobile_document_capture_url
      end
    end
  end
end
