require 'rails_helper'

describe LambdaCallback::AddressProofResultController do
  include IdvHelper

  describe '#create' do
    let(:document_capture_session) { DocumentCaptureSession.new(user: create(:user)) }
    let(:trace_id) { SecureRandom.uuid }

    context 'with valid API token' do
      before do
        request.headers['X-API-AUTH-TOKEN'] = AppConfig.env.address_proof_result_lambda_token
      end

      it 'accepts and stores successful address proofing results' do
        applicant = { phone: Faker::PhoneNumber.cell_phone }
        Idv::Agent.new(applicant).proof_address(document_capture_session, trace_id: trace_id)
        expect_address_proofing_job
        proofer_result = document_capture_session.load_proofing_result[:result]

        post :create, params: { result_id: document_capture_session.result_id,
                                address_result: proofer_result.to_h }

        proofing_result = document_capture_session.load_proofing_result
        expect(proofing_result.result).to include({ exception: '', success: 'true' })
      end

      it 'accepts and stores unsuccessful address proofing results' do
        applicant = {
          phone: IdentityIdpFunctions::AddressMockClient::UNVERIFIABLE_PHONE_NUMBER,
        }

        Idv::Agent.new(applicant).proof_address(document_capture_session, trace_id: trace_id)
        expect_address_proofing_job
        proofer_result = document_capture_session.load_proofing_result[:result]

        post :create, params: { result_id: document_capture_session.result_id,
                                address_result: proofer_result.to_h }

        proofing_result = document_capture_session.load_proofing_result
        expect(proofing_result.result[:success]).to eq 'false'
        expect(proofing_result.result[:errors]).to eq(
          { phone: ['The phone number could not be verified.'] },
        )
      end

      it 'sends notifications if result includes exceptions' do
        expect(NewRelic::Agent).to receive(:notice_error)
        expect(ExceptionNotifier).to receive(:notify_exception)

        applicant = {
          phone: IdentityIdpFunctions::AddressMockClient::PROOFER_TIMEOUT_PHONE_NUMBER,
        }

        document_capture_session.create_proofing_session
        Idv::Agent.new(applicant).proof_address(document_capture_session, trace_id: trace_id)
        expect_address_proofing_job
        proofer_result = document_capture_session.load_proofing_result[:result]

        post :create, params: { result_id: document_capture_session.result_id,
                                address_result: proofer_result.to_h }

        proofing_result = document_capture_session.load_proofing_result
        expect(proofing_result.result[:exception]).to start_with('#<Proofer::TimeoutError: ')
      end
    end

    context 'with invalid API token' do
      before do
        request.headers['X-API-AUTH-TOKEN'] = 'zyx'
      end

      it 'returns unauthorized error' do
        post :create, params: { result_id: 'abc123', address_result: {} }

        expect(response.status).to eq 401
      end
    end
  end
end
