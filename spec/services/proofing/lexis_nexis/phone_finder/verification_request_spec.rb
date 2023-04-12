require 'rails_helper'

describe Proofing::LexisNexis::PhoneFinder::VerificationRequest do
  let(:applicant) do
    {
      uuid_prefix: '0987',
      uuid: '1234-abcd',
      first_name: 'Testy',
      last_name: 'McTesterson',
      ssn: '123456789',
      dob: '01/01/1980',
      phone: '5551231234',
    }
  end
  let(:response_body) { LexisNexisFixtures.phone_finder_rdp1_success_response_json }
  subject { described_class.new(applicant: applicant, config: LexisNexisFixtures.example_config) }

  it_behaves_like 'a lexisnexis request'

  describe '#body' do
    it 'returns a properly formed request body' do
      expect(subject.body).to eq(LexisNexisFixtures.phone_finder_request_json)
    end

    context 'without a uuid_prefix' do
      let(:applicant) do
        hash = super()
        hash.delete(:uuid_prefix)
        hash
      end

      it 'does not prepend' do
        parsed_body = JSON.parse(subject.body, symbolize_names: true)
        expect(parsed_body[:Settings][:Reference]).to eq(applicant[:uuid])
      end
    end
  end

  describe '#url' do
    it 'returns a url for the Phone Finder endpoint' do
      expect(subject.url).to eq(
        'https://example.com/restws/identity/v2/test_account/customers.gsa2.phonefinder.workflow/conversation',
      )
    end
  end
end
