require 'rails_helper'

RSpec.describe ProofingAgent::ApplicantPiiTransformer do
  describe '#transform' do
    let(:id_type) { nil }
    let(:applicant) do
      {
        suspected_fraud: false,
        email: 'janesmith@example.com',
        first_name: 'Jane',
        last_name: 'Smith',
        dob: '1990-01-01',
        phone: '555-555-5555',
        ssn: '123-45-6789',
        id_type:,
      }
    end
    let(:residential_address) do
      {
        address1: '456 Elm St',
        address2: 'Apt 2',
        city: 'Othertown',
        state: 'NY',
        zip_code: '54321',
      }
    end
    let(:state_id) do
      {
        document_number: 'A1234567',
        jurisdiction: 'CA',
        expiration_date: '2030-01-01',
        issue_date: '2015-01-01',
        address1: '123 Main St',
        city: 'Anytown',
        state: 'CA',
        zip_code: '12345',
      }
    end
    let(:passport) do
      {
        expiration_date: '2030-01-01',
        issue_date: '2015-01-01',
        mrz: Idp::Constants::MOCK_IDV_APPLICANT_WITH_PASSPORT[:mrz],
        issuing_country_code: 'USA',
      }
    end

    context 'user proofs with a state id' do
      let(:id_type) { 'state_id' }

      context 'without a residential address' do
        subject do
          described_class.new(
            applicant.merge(
              state_id: state_id,
            ),
          )
        end

        it 'returns an applicant with state id' do
          expect(subject.transform).to include(
            suspected_fraud: false,
            email: 'janesmith@example.com',
            first_name: 'Jane',
            last_name: 'Smith',
            dob: '1990-01-01',
            phone: '555-555-5555',
            ssn: '123-45-6789',
            document_type_received: 'state_id',
            identity_doc_address1: '123 Main St',
            identity_doc_address2: nil,
            identity_doc_city: 'Anytown',
            identity_doc_address_state: 'CA',
            identity_doc_zipcode: '12345',
            state_id_number: 'A1234567',
            state_id_jurisdiction: 'CA',
            state_id_expiration: '2030-01-01',
            state_id_issued: '2015-01-01',
            same_address_as_id: 'true',
          )
        end
      end

      context 'with residential address' do
        subject do
          described_class.new(
            applicant.merge(
              state_id: state_id,
              residential_address: residential_address,
            ),
          )
        end

        it 'returns an applicant with state id and address' do
          expect(subject.transform).to include(
            suspected_fraud: false,
            email: 'janesmith@example.com',
            first_name: 'Jane',
            last_name: 'Smith',
            dob: '1990-01-01',
            phone: '555-555-5555',
            ssn: '123-45-6789',
            document_type_received: 'state_id',
            identity_doc_address1: '123 Main St',
            identity_doc_address2: nil,
            identity_doc_city: 'Anytown',
            identity_doc_address_state: 'CA',
            identity_doc_zipcode: '12345',
            address1: '456 Elm St',
            address2: 'Apt 2',
            city: 'Othertown',
            state: 'NY',
            zipcode: '54321',
            state_id_number: 'A1234567',
            state_id_jurisdiction: 'CA',
            state_id_expiration: '2030-01-01',
            state_id_issued: '2015-01-01',
            same_address_as_id: 'false',
          )
        end
      end
    end

    context 'user proofs with a passport' do
      let(:id_type) { 'passport' }

      subject do
        described_class.new(
          applicant.merge(
            residential_address: residential_address,
            passport: passport,
          ),
        )
      end

      it 'returns an applicant with passport' do
        expect(subject.transform).to include(
          suspected_fraud: false,
          email: 'janesmith@example.com',
          first_name: 'Jane',
          last_name: 'Smith',
          dob: '1990-01-01',
          phone: '555-555-5555',
          ssn: '123-45-6789',
          document_type_received: 'passport',
          address1: '456 Elm St',
          address2: 'Apt 2',
          city: 'Othertown',
          state: 'NY',
          zipcode: '54321',
          passport_expiration: '2030-01-01',
          passport_issued: '2015-01-01',
          mrz: Idp::Constants::MOCK_IDV_APPLICANT_WITH_PASSPORT[:mrz],
          issuing_country_code: 'USA',
          same_address_as_id: 'false',
        )
      end
    end
  end
end
