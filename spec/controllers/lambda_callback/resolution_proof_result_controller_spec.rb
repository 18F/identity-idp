require 'rails_helper'

describe LambdaCallback::ResolutionProofResultController do
  describe '#create' do
    let(:document_capture_session) { DocumentCaptureSession.new(user: create(:user)) }
    let(:trace_id) { SecureRandom.uuid }

    context 'with valid API token' do
      before do
        request.headers['X-API-AUTH-TOKEN'] = AppConfig.env.resolution_proof_result_lambda_token
      end

      it 'accepts and stores successful resolution proofing results' do
        applicant = { first_name: Faker::Name.first_name, ssn: Faker::IDNumber.valid,
                      zipcode: Faker::Address.zip_code, state_id_number: '123',
                      state_id_type: 'drivers_license', state_id_jurisdiction: 'WI' }
        document_capture_session.store_proofing_pii_from_doc(applicant)
        Idv::Agent.new(applicant).proof_resolution(
          document_capture_session,
          should_proof_state_id: true,
          trace_id: trace_id,
        )
        proofer_result = document_capture_session.load_proofing_result[:result]

        post :create, params: { result_id: document_capture_session.result_id,
                                resolution_result: proofer_result.to_h }

        proofing_result = document_capture_session.load_proofing_result
        expect(proofing_result.result).to include(exception: '', success: 'true')
      end

      it 'accepts and stores unsuccessful resolution proofing results' do
        applicant = { first_name: 'Bad Name', ssn: Faker::IDNumber.valid,
                      zipcode: Faker::Address.zip_code }
        document_capture_session.store_proofing_pii_from_doc(applicant)
        Idv::Agent.new(applicant).proof_resolution(
          document_capture_session,
          should_proof_state_id: false,
          trace_id: trace_id,
        )
        proofer_result = document_capture_session.load_proofing_result[:result]

        post :create, params: { result_id: document_capture_session.result_id,
                                resolution_result: proofer_result.to_h }

        proofing_result = document_capture_session.load_proofing_result
        expect(proofing_result.result[:success]).to eq 'false'
        expect(proofing_result.result[:errors]).to eq(
          { first_name: ['Unverified first name.'] },
        )
      end

      it 'sends notifications if result includes exceptions' do
        expect(NewRelic::Agent).to receive(:notice_error)
        expect(ExceptionNotifier).to receive(:notify_exception)

        applicant = { first_name: 'Time', ssn: Faker::IDNumber.valid,
                      zipcode: Faker::Address.zip_code }

        document_capture_session.store_proofing_pii_from_doc(applicant)
        Idv::Agent.new(applicant).proof_resolution(
          document_capture_session,
          should_proof_state_id: false,
          trace_id: trace_id,
        )
        proofer_result = document_capture_session.load_proofing_result[:result]

        post :create, params: { result_id: document_capture_session.result_id,
                                resolution_result: proofer_result.to_h }

        proofing_result = document_capture_session.load_proofing_result
        expect(proofing_result.result[:exception]).to start_with('#<Proofer::TimeoutError: ')
      end
    end

    context 'with invalid API token' do
      before do
        request.headers['X-API-AUTH-TOKEN'] = 'zyx'
      end

      it 'returns unauthorized error' do
        post :create, params: { result_id: 'abc123', resolution_result: {} }

        expect(response.status).to eq 401
      end
    end
  end
end
