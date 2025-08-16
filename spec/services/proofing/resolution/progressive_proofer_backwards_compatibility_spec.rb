# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Proofing::Resolution::ProgressiveProofer do
  describe 'backwards compatibility for document type fields' do
    let(:user_uuid) { SecureRandom.uuid }
    let(:user_email) { Faker::Internet.email }
    let(:proofing_vendor) { :instant_verify }
    let(:progressive_proofer) do
      described_class.new(
        user_uuid: user_uuid,
        user_email: user_email,
        proofing_vendor: proofing_vendor,
      )
    end

    describe '#passport_applicant?' do
      context 'with new field name (document_type_received)' do
        let(:applicant_pii) do
          {
            document_type_received: 'passport',
            first_name: 'Test',
            last_name: 'User',
          }
        end

        it 'correctly identifies passport applicant' do
          expect(progressive_proofer.send(:passport_applicant?, applicant_pii)).to be true
        end
      end

      context 'with old field name (id_doc_type)' do
        let(:applicant_pii) do
          {
            id_doc_type: 'passport',
            first_name: 'Test',
            last_name: 'User',
          }
        end

        it 'correctly identifies passport applicant using old field name' do
          expect(progressive_proofer.send(:passport_applicant?, applicant_pii)).to be true
        end
      end

      context 'with both field names present (new takes precedence)' do
        let(:applicant_pii) do
          {
            document_type_received: 'passport',
            id_doc_type: 'drivers_license',
            first_name: 'Test',
            last_name: 'User',
          }
        end

        it 'uses new field name when both are present' do
          expect(progressive_proofer.send(:passport_applicant?, applicant_pii)).to be true
        end
      end

      context 'with non-passport document using new field' do
        let(:applicant_pii) do
          {
            document_type_received: 'drivers_license',
            first_name: 'Test',
            last_name: 'User',
          }
        end

        it 'correctly identifies non-passport applicant' do
          expect(progressive_proofer.send(:passport_applicant?, applicant_pii)).to be false
        end
      end

      context 'with non-passport document using old field' do
        let(:applicant_pii) do
          {
            id_doc_type: 'drivers_license',
            first_name: 'Test',
            last_name: 'User',
          }
        end

        it 'correctly identifies non-passport applicant using old field' do
          expect(progressive_proofer.send(:passport_applicant?, applicant_pii)).to be false
        end
      end

      context 'with neither field present' do
        let(:applicant_pii) do
          {
            first_name: 'Test',
            last_name: 'User',
          }
        end

        it 'returns false when document type is not specified' do
          expect(progressive_proofer.send(:passport_applicant?, applicant_pii)).to be false
        end
      end
    end
  end
end
