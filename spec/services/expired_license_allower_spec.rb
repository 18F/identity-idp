require 'rails_helper'

RSpec.describe ExpiredLicenseAllower do
  subject(:allower) { ExpiredLicenseAllower.new(response) }

  let(:proofing_allow_expired_license) { false }
  let(:proofing_expired_license_after) { Date.today }

  let(:response) { IdentityDocAuth::Response.new }

  before do
    allow(IdentityConfig.store).to receive(:proofing_allow_expired_license).
      and_return(proofing_allow_expired_license)
    allow(IdentityConfig.store).to receive(:proofing_expired_license_after).
      and_return(proofing_expired_license_after)
  end

  describe '#processed_response' do
    subject(:processed_response) { allower.processed_response }

    context 'for a response that has no errors' do
      let(:response) { IdentityDocAuth::Response.new(success: true) }

      it 'does not change the response' do
        expect(processed_response).to eq(response)
      end
    end

    context 'for a response that has multiple errors' do
      let(:response) do
        IdentityDocAuth::Response.new(
          success: false,
          errors: {
            id: [IdentityDocAuth::Errors::EXPIRATION_CHECKS],
            front: [IdentityDocAuth::Errors::VISIBLE_PHOTO_CHECK],
          }
        )
      end

      it 'does not change the response' do
        expect(processed_response).to eq(response)
      end
    end

    context 'for a response that only has DOCUMENT_EXPIRED_CHECK error' do
      let(:response) do
        IdentityDocAuth::Response.new(
          success: false,
          pii_from_doc: pii_from_doc,
          errors: {
            id: [IdentityDocAuth::Errors::DOCUMENT_EXPIRED_CHECK],
          },
        )
      end

      let(:pii_from_doc) { {} }

      context 'when proofing_allow_expired_license is true' do
        let(:proofing_allow_expired_license) { true }

        context 'when the response PII does not have state_id_expiration' do
          let(:pii_from_doc) { {} }

          it 'does not change the response' do
            expect(processed_response).to eq(response)
          end
        end

        context 'when the response PII has a state_id_expiration' do
          let(:proofing_expired_license_after) { Date.new(2021, 3, 1) }

          context 'when the state_id_expiration is before proofing_expired_license_after' do
            let(:pii_from_doc) { { state_id_expiration: '01/01/2021' } }

            it 'does not change the response' do
              expect(processed_response).to eq(response)
            end
          end

          context 'when the state_id_expiration is after proofing_expired_license_after' do
            let(:pii_from_doc) { { state_id_expiration: '04/01/2021' } }

            it 'returns a successful response with expired_document and reproof_at' do
              expect(processed_response).to_not eq(response)

              expect(processed_response.success?).to eq(true)
              expect(processed_response.extra[:expired_document]).to eq(true)
              expect(processed_response.extra[:reproof_at]).to eq('2023-03-01')
            end
          end
        end
      end

      context 'when proofing_allow_expired_license is false' do
        let(:proofing_allow_expired_license) { false }

        it 'does not change the response' do
          expect(processed_response).to eq(response)
        end
      end
    end
  end
end
