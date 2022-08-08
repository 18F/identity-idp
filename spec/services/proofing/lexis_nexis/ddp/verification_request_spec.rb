require 'rails_helper'

describe Proofing::LexisNexis::Ddp::VerificationRequest do
  let(:dob) { '01/01/1980' }
  let(:applicant) do
    {
      first_name: 'Testy',
      last_name: 'McTesterson',
      ssn: '123-45-6789',
      dob: dob,
      address1: '123 Main St',
      address2: 'Ste 3',
      city: 'Baton Rouge',
      state: 'LA',
      zipcode: '70802-12345',
      state_id_number: '12345678',
      session_id: '123456',
      phone: '5551231234',
      email: 'test@example.com',
    }
  end

  let(:response_body) { LexisNexisFixtures.ddp_success_response_json }
  subject { described_class.new(applicant: applicant, config: LexisNexisFixtures.example_ddp_config) }

  describe '#body' do
    it 'returns a properly formed request body' do
      puts subject.body
      puts
      expect(subject.body).to eq(LexisNexisFixtures.ddp_request_json)
    end

    context 'without an address line 2' do
      let(:applicant) do
        hash = super()
        hash.delete(:address2)
        hash
      end

      it 'sets StreetAddress2 to and empty string' do
        parsed_body = JSON.parse(subject.body, symbolize_names: true)
        expect(parsed_body[:account_address_street2]).to eq('')
      end
    end
  end

  describe '#url' do
    it 'returns a url for the DDP session query endpoint' do
      expect(subject.url).to eq('https://example.com/api/session-query')
    end
  end
end
