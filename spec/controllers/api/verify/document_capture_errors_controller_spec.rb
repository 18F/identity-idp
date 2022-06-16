require 'rails_helper'

describe Api::Verify::DocumentCaptureErrorsController do
  let(:user) { create(:user) }

  it 'extends behavior of base api class' do
    expect(subject).to be_kind_of Api::Verify::BaseController
  end

  describe '#delete' do
    it 'renders as unauthorized (401)' do
      delete :delete

      expect(response.status).to eq(401)
    end

    shared_examples 'deleting document capture errors' do
      let(:params) { nil }

      subject(:response) { delete :delete, params: params }
      let(:parsed_body) { JSON.parse(response.body, symbolize_names: true) }

      it 'renders errors for missing fields' do
        expect(response.status).to eq 400
        expect(parsed_body).to eq(
          { errors: { document_capture_session_uuid: [t('errors.messages.blank')] } },
        )
      end

      context 'with invalid document capture session' do
        let(:params) { { document_capture_session_uuid: 'invalid' } }

        it 'renders errors for invalid document capture session' do
          expect(response.status).to eq 400
          expect(parsed_body).to eq(
            { errors: { document_capture_session_uuid: ['Invalid document capture session'] } },
          )
        end
      end

      context 'with valid document capture session' do
        let(:document_capture_session) do
          DocumentCaptureSession.create(user: user, ocr_confirmation_pending: true)
        end
        let(:params) { { document_capture_session_uuid: document_capture_session.uuid } }

        it 'deletes errors and renders successful response' do
          expect { response }.
            to change { document_capture_session.reload.ocr_confirmation_pending }.
            from(true).
            to(false)

          expect(response.status).to eq 200
          expect(parsed_body).to eq({})
        end
      end
    end

    context 'with signed in user' do
      before { stub_sign_in(user) }

      it_behaves_like 'deleting document capture errors'
    end

    context 'with hybrid effective user' do
      before { session[:doc_capture_user_id] = user.id }

      it_behaves_like 'deleting document capture errors'
    end
  end
end
