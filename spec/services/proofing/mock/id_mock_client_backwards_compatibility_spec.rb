# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Proofing::Mock::IdMockClient do
  describe 'backwards compatibility for document type fields' do
    let(:mock_client) { described_class.new }
    let(:base_applicant) do
      {
        first_name: 'Test',
        last_name: 'User',
        dob: '1990-01-01',
        state_id_number: '123456789',
        state_id_jurisdiction: 'ND', # Use ND as it's a supported jurisdiction
      }
    end

    describe '#proof with document type validation' do
      context 'with new field name (document_type_received)' do
        context 'valid document type' do
          let(:applicant) do
            base_applicant.merge(document_type_received: 'drivers_license')
          end

          it 'returns success' do
            result = mock_client.proof(applicant)
            expect(result.success?).to be true
            expect(result.errors).to be_empty
          end
        end

        context 'invalid document type' do
          let(:applicant) do
            base_applicant.merge(document_type_received: 'invalid_type')
          end

          it 'returns error for invalid document type' do
            result = mock_client.proof(applicant)
            expect(result.success?).to be false
            expect(result.errors[:document_type_received]).to include(
              'The state ID type could not be verified',
            )
          end
        end
      end

      context 'with old field name (id_doc_type)' do
        context 'valid document type' do
          let(:applicant) do
            base_applicant.merge(id_doc_type: 'state_id_card')
          end

          it 'returns success using old field name' do
            result = mock_client.proof(applicant)
            expect(result.success?).to be true
            expect(result.errors).to be_empty
          end
        end

        context 'invalid document type' do
          let(:applicant) do
            base_applicant.merge(id_doc_type: 'invalid_type')
          end

          it 'returns error for invalid document type using old field' do
            result = mock_client.proof(applicant)
            expect(result.success?).to be false
            expect(result.errors[:document_type_received]).to include(
              'The state ID type could not be verified',
            )
          end
        end
      end

      context 'with both field names (new takes precedence)' do
        let(:applicant) do
          base_applicant.merge(
            document_type_received: 'drivers_license',
            id_doc_type: 'invalid_type',
          )
        end

        it 'uses new field name when both are present' do
          result = mock_client.proof(applicant)
          expect(result.success?).to be true
          expect(result.errors).to be_empty
        end
      end
    end

    describe '#jurisdiction_not_supported? with passport check' do
      context 'with new field name (document_type_received)' do
        context 'passport document' do
          let(:applicant) do
            base_applicant.merge(
              document_type_received: 'passport',
              state_id_jurisdiction: 'ZZ', # unsupported jurisdiction
            )
          end

          it 'returns false for passport regardless of jurisdiction' do
            result = mock_client.proof(applicant)
            expect(result.success?).to be true
            expect(result.errors[:state_id_jurisdiction]).to be_nil
          end
        end

        context 'non-passport document with unsupported jurisdiction' do
          let(:applicant) do
            base_applicant.merge(
              document_type_received: 'drivers_license',
              state_id_jurisdiction: 'ZZ',
            )
          end

          it 'returns error for unsupported jurisdiction' do
            result = mock_client.proof(applicant)
            expect(result.success?).to be false
            expect(result.errors[:state_id_jurisdiction]).to include(
              'The jurisdiction could not be verified',
            )
          end
        end
      end

      context 'with old field name (id_doc_type)' do
        context 'passport document' do
          let(:applicant) do
            base_applicant.merge(
              id_doc_type: 'passport',
              state_id_jurisdiction: 'ZZ',
            )
          end

          it 'returns false for passport using old field name' do
            result = mock_client.proof(applicant)
            expect(result.success?).to be true
            expect(result.errors[:state_id_jurisdiction]).to be_nil
          end
        end
      end
    end
  end
end
