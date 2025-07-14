require 'rails_helper'

RSpec.describe DocAuth::Socure::Requests::DocvResultRequest do
  let(:user) { create(:user) }
  let(:customer_user_id) { user.uuid }
  let(:user_email) { Faker::Internet.email }
  let(:document_capture_session_uuid) { 'fake uuid' }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:doc_type) { '' }
  let(:decision_value) { '' }

  subject(:docv_result_request) do
    described_class.new(
      customer_user_id:,
      document_capture_session_uuid:,
      user_email:,
    )
  end

  describe '#fetch' do
    let(:fake_socure_endpoint) { 'https://fake-socure.test/' }
    let(:fake_socure_api_endpoint) { 'https://fake-socure.test/api/3.0/EmailAuthScore' }
    let(:docv_transaction_token) { 'fake docv transaction token' }
    let(:document_capture_session) do
      create(
        :document_capture_session,
        user:,
        socure_docv_transaction_token: docv_transaction_token,
      )
    end

    before do
      allow(IdentityConfig.store).to receive(:socure_idplus_base_url)
        .and_return(fake_socure_endpoint)
      allow(DocumentCaptureSession).to receive(:find_by).and_return(document_capture_session)
    end

    context 'when the docv request is successful' do
      let(:response)  { docv_result_request.fetch }

      before do
        stub_request(:post, fake_socure_api_endpoint)
          .with(body: {
            modules: ['documentverification'],
            docvTransactionToken: docv_transaction_token,
            customerUserId: customer_user_id,
            email: user_email,
          })
          .to_return(
            status: 200,
            body: {
              documentVerification: {
                decision: {
                  value: decision_value,
                },
                documentType: {
                  type: doc_type,
                },
              },
            }.to_json,
          )
      end

      it 'returns a DocvResultResponse' do
        expect(response).to be_instance_of(DocAuth::Socure::Responses::DocvResultResponse)
      end

      context 'passports enabled' do
        before do
          allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled).and_return(true)
          allow(IdentityConfig.store).to receive(:doc_auth_passport_vendor_default)
            .and_return(Idp::Constants::Vendors::SOCURE)
        end

        context 'fails if doc types do not match passport request dl submitted' do
          let(:document_capture_session) do
            create(
              :document_capture_session,
              user:,
              socure_docv_transaction_token: docv_transaction_token,
              passport_status: 'requested',
            )
          end
          let(:doc_type) { 'Drivers License' }
          let(:decision_value) { 'accept' }

          it 'returns a DocAuth::Response failure' do
            expect(response.to_h).to include(
              success: false,
              errors: {
                unexpected_id_type: true,
              },
              vendor: 'Socure',
            )
          end
        end
        context 'fails if doc types do not match dl requested passport submitted' do
          let(:document_capture_session) do
            create(
              :document_capture_session,
              user:,
              socure_docv_transaction_token: docv_transaction_token,
              passport_status: 'allowed',
            )
          end
          let(:doc_type) { 'Passport' }
          let(:decision_value) { 'accept' }

          it 'returns a DocAuth::Response failure' do
            expect(response.to_h).to include(
              success: false,
              errors: {
                unexpected_id_type: true,
              },
              vendor: 'Socure',
            )
          end
        end
      end
    end

    context 'when the docv request fails' do
      let(:response)  { docv_result_request.fetch }
      let(:status) { 'Error' }
      let(:reference_id) { '360ae43f-123f-47ab-8e05-6af79752e76c' }
      let(:msg) { 'InternalServerException' }
      let(:fake_socure_response) { { status:, referenceId: reference_id, msg: } }
      let(:fake_socure_status) { 500 }

      context 'when the failure is connection failed' do
        before do
          stub_request(:post, fake_socure_api_endpoint).to_raise(Faraday::ConnectionFailed)
        end

        it 'returns a DocAuth::Response failure' do
          expect(response.to_h).to include(
            success: false,
            errors: {
              network: true,
            },
            vendor: 'Socure',
            exception: an_instance_of(Faraday::ConnectionFailed),
          )
        end
      end

      context 'when the failure is a socure failure' do
        before do
          stub_request(:post, fake_socure_api_endpoint)
            .to_return(
              status: fake_socure_status,
              body: JSON.generate(fake_socure_response),
            )
        end

        it 'returns a DocAuth::Response failure' do
          expect(response.to_h).to include(
            success: false,
            errors: {
              network: true,
            },
            vendor: 'Socure',
            reference_id: reference_id,
            exception: an_instance_of(DocAuth::RequestError),
          )
        end
      end
    end
  end
end
