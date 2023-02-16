require 'rails_helper'

describe Proofing::Aamva::VerificationClient do
  let(:applicant) do
    applicant = Proofing::Aamva::Applicant.from_proofer_applicant(
      uuid: '1234-4567-abcd-efgh',
      first_name: 'Testy',
      last_name: 'McTesterson',
      dob: '10/29/1942',
    )
    applicant.state_id_data.merge!(
      state_id_number: '123456789',
      state_id_jurisdiction: 'CA',
      state_id_type: 'drivers_license',
    )
    applicant
  end

  subject(:verification_client) { described_class.new(AamvaFixtures.example_config) }

  describe '#send_verification_request' do
    before do
      auth_client = instance_double(Proofing::Aamva::AuthenticationClient)
      allow(auth_client).to receive(:fetch_token).and_return('ThisIsTheToken')
      allow(Proofing::Aamva::AuthenticationClient).to receive(:new).and_return(auth_client)
    end

    it 'gets the auth token from the auth client' do
      verification_stub = stub_request(:post, AamvaFixtures.example_config.verification_url).
        to_return(body: AamvaFixtures.verification_response, status: 200).
        with do |request|
          xml_text_at_path(request.body, '//ns:token').gsub(/\s/, '') == 'ThisIsTheToken'
        end

      verification_client.send_verification_request(
        applicant: applicant,
        session_id: '1234-abcd-efgh',
      )

      expect(verification_stub).to have_been_requested
    end
  end

  describe '#send_verification_request' do
    let(:response_body) { AamvaFixtures.verification_response }

    before do
      auth_client = instance_double(Proofing::Aamva::AuthenticationClient)
      allow(auth_client).to receive(:fetch_token).and_return('ThisIsTheToken')
      allow(Proofing::Aamva::AuthenticationClient).to receive(:new).and_return(auth_client)

      stub_request(:post, AamvaFixtures.example_config.verification_url).
        to_return(body: response_body, status: 200)
    end

    let(:response) do
      verification_client.send_verification_request(
        applicant: applicant,
        session_id: '1234-abcd-efgh',
      )
    end

    context 'when verification is successful' do
      it 'returns a successful response' do
        expect(response).to be_a Proofing::Aamva::Response::VerificationResponse
        expect(response.success?).to eq(true)
      end
    end

    context 'when verification is not successful' do
      let(:response_body) do
        modify_xml_at_xpath(
          AamvaFixtures.verification_response,
          '//PersonBirthDateMatchIndicator',
          'false',
        )
      end

      it 'returns an unsuccessful response with errors' do
        expect(response).to be_a Proofing::Aamva::Response::VerificationResponse
        expect(response.success?).to eq(false)
      end
    end
  end
end
