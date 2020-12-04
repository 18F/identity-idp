require 'rails_helper'

describe LambdaCallback::DocumentProofResultController do
  describe '#create' do
    let(:pii) do
      {
        'first_name' => Faker::Name.first_name,
        'last_name' => Faker::Name.last_name,
        'dob' => '2020-01-02',
        'zipcode' => Faker::Address.zip_code,
        'state_id_number' => '123',
        'state_id_type' => 'drivers_license',
        'state_id_jurisdiction' => 'WI',
      }
    end
    let(:idv_result) { { success: true, errors: {}, messages: ['some message'] } }
    let(:document_capture_session) { DocumentCaptureSession.new(user: create(:user)) }

    context 'with valid API token' do
      before do
        request.headers['X-API-AUTH-TOKEN'] = AppConfig.env.document_proof_result_lambda_token
        document_capture_session.store_proofing_pii_from_doc({}) # generates a result_id
      end

      it 'accepts and stores pii and successful document proofing results' do
        post :create, params: {
          result_id: document_capture_session.result_id,
          document_result: {
            success: true,
            exception: '',
            pii_from_doc: pii,
          },
        }, as: :json

        proofing_result = document_capture_session.load_doc_auth_async_result
        expect(proofing_result.result).to include(
          exception: '',
          success: true,
        )
        expect(proofing_result.pii).to eq(pii.symbolize_keys)
      end

      it 'accepts and stores unsuccessful document proofing results' do
        post :create, params: { result_id: document_capture_session.result_id,
                                document_result: { success: false, exception: '' } }

        proofing_result = document_capture_session.load_doc_auth_async_result
        expect(proofing_result.result[:success]).to eq 'false'
      end

      it 'sends notifications if result includes exceptions' do
        post :create, params: { result_id: document_capture_session.result_id,
                                document_result: { success: false,
                                                   exception: '#<Proofer::TimeoutError: ' } }

        proofing_result = document_capture_session.load_doc_auth_async_result
        expect(proofing_result.result[:exception]).to start_with('#<Proofer::TimeoutError: ')
      end
    end

    context 'with invalid result_id' do
      before do
        request.headers['X-API-AUTH-TOKEN'] = AppConfig.env.document_proof_result_lambda_token
      end

      it 'returns 404' do
        post :create, params: {
          result_id: '0000',
          document_result: {
          },
        }, as: :json

        expect(response.status).to eq 404
      end
    end

    context 'with invalid API token' do
      before do
        request.headers['X-API-AUTH-TOKEN'] = 'zyx'
      end

      it 'returns unauthorized error' do
        post :create, params: { result_id: 'abc123', document_result: {} }

        expect(response.status).to eq 401
      end
    end
  end
end
