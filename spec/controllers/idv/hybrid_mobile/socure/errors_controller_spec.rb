require 'rails_helper'

RSpec.describe Idv::HybridMobile::Socure::ErrorsController do
  let(:user) { create(:user) }
  let(:document_capture_session) do
    create(
      :document_capture_session,
      user:,
      requested_at: Time.zone.now,
      doc_auth_vendor: Idp::Constants::Vendors::SOCURE,
      mdl_enabled: true,
      document_type_requested: Idp::Constants::DocumentTypes::MDL,
    )
  end

  before do
    stub_analytics

    session[:doc_capture_user_id] = user.id
    session[:document_capture_session_uuid] = document_capture_session.uuid
  end

  describe '#show' do
    context 'when error_code is mdl_not_found' do
      it 'redirects to choose id type with mdl disabled' do
        get(:show, params: { error_code: 'mdl_not_found' })

        expect(response).to redirect_to idv_hybrid_mobile_choose_id_type_url(disable_mdl: true)
      end

      it 'disables mdl on the document capture session' do
        expect { get(:show, params: { error_code: 'mdl_not_found' }) }
          .to change { document_capture_session.reload.mdl_enabled }
          .from(true).to(false)
      end

      it 'logs an event with the error code' do
        get(:show, params: { error_code: 'mdl_not_found' })

        expect(@analytics).to have_logged_event(
          :idv_doc_auth_socure_error_visited,
          hash_including(error_code: 'mdl_not_found'),
        )
      end
    end
  end
end
