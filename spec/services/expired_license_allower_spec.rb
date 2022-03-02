require 'rails_helper'

RSpec.describe ExpiredLicenseAllower do
  subject(:allower) { ExpiredLicenseAllower.new(response) }

  let(:proofing_allow_expired_license) { false }
  let(:proofing_expired_license_after) { Date.new(2021, 3, 1) }

  let(:response) { DocAuth::Response.new }

  before do
    allow(IdentityConfig.store).to receive(:proofing_allow_expired_license).
      and_return(proofing_allow_expired_license)
    allow(IdentityConfig.store).to receive(:proofing_expired_license_after).
      and_return(proofing_expired_license_after)
  end

  describe '#processed_response' do
    subject(:processed_response) { allower.processed_response }

    context 'for a response that has no errors' do
      let(:response) { DocAuth::Response.new(success: true) }

      it 'does not change the response' do
        expect(processed_response).to eq(response)
      end
    end

    context 'for a response that has DOCUMENT_EXPIRED_CHECK and other errors' do
      let(:response) do
        DocAuth::Response.new(
          success: false,
          errors: {
            id: [
              DocAuth::Errors::DOCUMENT_EXPIRED_CHECK,
              DocAuth::Errors::EXPIRATION_CHECKS,
            ],
            front: [DocAuth::Errors::VISIBLE_PHOTO_CHECK],
          },
        )
      end

      it 'does not change the response success' do
        expect(processed_response.success?).to eq(response.success?)
      end

      it 'adds document_expired and would_have_passed' do
        expect(processed_response.extra).to include(
          document_expired: true,
          would_have_passed: false,
        )
      end
    end

    context 'for a response that only has DOCUMENT_EXPIRED_CHECK error' do
      let(:response) do
        DocAuth::Response.new(
          success: false,
          pii_from_doc: pii_from_doc,
          errors: {
            id: [DocAuth::Errors::DOCUMENT_EXPIRED_CHECK],
          },
        )
      end

      let(:pii_from_doc) { {} }

      context 'when proofing_allow_expired_license is true' do
        let(:proofing_allow_expired_license) { true }

        context 'when the response PII does not have state_id_expiration' do
          let(:pii_from_doc) { {} }

          it 'does not change the success' do
            expect(processed_response.success?).to eq(false)
          end
        end

        context 'when the response PII has a state_id_expiration' do
          let(:proofing_expired_license_after) { Date.new(2021, 3, 1) }

          context 'when the state_id_expiration is before proofing_expired_license_after' do
            let(:pii_from_doc) { { state_id_expiration: '2021-01-01' } }

            it 'does not change the success' do
              expect(processed_response.success?).to eq(false)
            end
          end

          context 'when the state_id_expiration is after proofing_expired_license_after' do
            let(:pii_from_doc) { { state_id_expiration: '2021-04-01' } }

            it 'returns a successful response with document_expired' do
              expect(processed_response).to_not eq(response)

              expect(processed_response.success?).to eq(true)
              expect(processed_response.extra[:document_expired]).to eq(true)
            end

            it 'overrides the errors to be blank' do
              expect(processed_response.errors).to eq({})
            end
          end
        end
      end

      context 'when proofing_allow_expired_license is false' do
        let(:proofing_allow_expired_license) { false }

        it 'does not change the success' do
          expect(processed_response.success?).to eq(false)
        end

        context 'when the state_id_expiration is before proofing_expired_license_after' do
          let(:pii_from_doc) { { state_id_expiration: '2021-01-01' } }

          it 'has would_have_passed false' do
            expect(processed_response.extra).to include(
              document_expired: true,
              would_have_passed: false,
            )
          end
        end

        context 'when the state_id_expiration is after proofing_expired_license_after' do
          let(:pii_from_doc) { { state_id_expiration: '2021-04-01' } }

          it 'has would_have_passed true' do
            expect(processed_response.extra).to include(
              document_expired: true,
              would_have_passed: true,
            )
          end
        end
      end
    end
  end
end
