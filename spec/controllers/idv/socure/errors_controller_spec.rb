require 'rails_helper'

RSpec.describe Idv::Socure::ErrorsController do
  let(:user) { create(:user) }

  before do
    stub_analytics
    stub_sign_in(user)
    subject.idv_session.socure_docv_wait_polling_started_at = Time.zone.now
  end

  describe '#show' do
    it 'logs an event' do
      get(:show)

      expect(@analytics).to have_logged_event(:idv_doc_auth_socure_error_visited)
    end

    it 'uses the transaction token from params' do
      transaction_token = 'test-transaction-token'

      get(:show, params: { transaction_token: transaction_token })

      expect(@analytics).to have_logged_event(
        :idv_doc_auth_socure_error_visited,
        hash_including(docv_transaction_token: transaction_token),
      )
    end

    context 'when error_code is mdl_not_found' do
      let(:document_capture_session) do
        create(
          :document_capture_session,
          user:,
          mdl_enabled: true,
          document_type_requested: Idp::Constants::DocumentTypes::MDL,
        )
      end

      before do
        subject.idv_session.document_capture_session_uuid = document_capture_session.uuid
      end

      it 'redirects to choose id type with mdl disabled' do
        get(:show, params: { error_code: 'mdl_not_found' })

        expect(response).to redirect_to idv_choose_id_type_url(disable_mdl: true)
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

      context 'without a document capture session' do
        before do
          subject.idv_session.document_capture_session_uuid = nil
        end

        it 'still redirects to choose id type' do
          get(:show, params: { error_code: 'mdl_not_found' })

          expect(response).to redirect_to idv_choose_id_type_url(disable_mdl: true)
        end
      end
    end
  end
end
