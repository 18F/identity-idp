# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Proofing::Aamva::Applicant do
  describe 'backwards compatibility for document type fields' do
    describe '.from_proofer_applicant' do
      let(:base_applicant) do
        {
          uuid: SecureRandom.uuid,
          first_name: 'Test',
          last_name: 'User',
          dob: '1990-01-01',
          state_id_number: 'ABC123',
          state_id_jurisdiction: 'CA',
        }
      end

      context 'with new field name (document_type_received)' do
        let(:applicant) do
          base_applicant.merge(document_type_received: 'drivers_license')
        end

        it 'creates AAMVA applicant with correct document type' do
          aamva_applicant = described_class.from_proofer_applicant(applicant)
          expect(aamva_applicant.state_id_data.document_type_received).to eq('drivers_license')
        end
      end

      context 'with old field name (id_doc_type)' do
        let(:applicant) do
          base_applicant.merge(id_doc_type: 'state_id_card')
        end

        it 'creates AAMVA applicant using old field name' do
          aamva_applicant = described_class.from_proofer_applicant(applicant)
          expect(aamva_applicant.state_id_data.document_type_received).to eq('state_id_card')
        end
      end

      context 'with both field names (new takes precedence)' do
        let(:applicant) do
          base_applicant.merge(
            document_type_received: 'passport',
            id_doc_type: 'drivers_license',
          )
        end

        it 'uses new field name when both are present' do
          aamva_applicant = described_class.from_proofer_applicant(applicant)
          expect(aamva_applicant.state_id_data.document_type_received).to eq('passport')
        end
      end

      context 'with neither field present' do
        let(:applicant) { base_applicant }

        it 'sets document_type_received to nil' do
          aamva_applicant = described_class.from_proofer_applicant(applicant)
          expect(aamva_applicant.state_id_data.document_type_received).to be_nil
        end
      end
    end
  end
end
