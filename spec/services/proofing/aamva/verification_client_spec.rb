require 'rails_helper'

RSpec.describe Proofing::Aamva::VerificationClient do
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
      allow(Proofing::Aamva::AuthenticationClient).to receive(:auth_token).
        and_return('ThisIsTheToken')
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
    let(:response_http_status) { 200 }

    before do
      allow(Proofing::Aamva::AuthenticationClient).to receive(:auth_token).
        and_return('ThisIsTheToken')

      stub_request(:post, AamvaFixtures.example_config.verification_url).
        to_return(body: response_body, status: response_http_status)
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
      context 'because we have a valid response and a 200 status, but the response says "no"' do
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

      context 'because we have a valid response and a non-200 status, and the response says "no"' do
        let(:response_body) do
          modify_xml_at_xpath(
            AamvaFixtures.verification_response,
            '//PersonBirthDateMatchIndicator',
            'false',
          )
        end
        let(:response_http_status) { 500 }

        it 'throws an exception about the status code' do
          expect { response }.to raise_error(
            Proofing::Aamva::VerificationError,
            /Unexpected status code in response: 500/,
          )
        end
      end

      context 'because we have an MVA timeout and 500 status' do
        let(:response_body) { AamvaFixtures.soap_fault_response }
        let(:response_http_status) { 500 }

        it 'throws an exception about the MVA timeout' do
          expect { response }.to raise_error(
            Proofing::Aamva::VerificationError,
            /#{Proofing::StateIdResult::MVA_TIMEOUT_EXCEPTION}/o,
          )
        end

        it 'throws an exception about the status code' do
          expect { response }.to raise_error(
            Proofing::Aamva::VerificationError,
            /Unexpected status code in response: 500/,
          )
        end
      end

      context 'because we have an MVA timeout and 200 status' do
        let(:response_body) { AamvaFixtures.soap_fault_response }
        let(:response_http_status) { 200 }

        it 'parses the raw response body' do
          begin
            response
          rescue Proofing::Aamva::VerificationError
          end
        end

        it 'throws an exception about the MVA timeout' do
          expect { response }.to raise_error(
            Proofing::Aamva::VerificationError,
            /#{Proofing::StateIdResult::MVA_TIMEOUT_EXCEPTION}/o,
          )
        end
      end

      context 'because we have an invalid response and a 200 status' do
        let(:response_body) { 'error: computer has no brain.<br>' }

        it 'tries to parse the raw response body' do
          begin
            response
          rescue Proofing::Aamva::VerificationError
          end
        end

        it 'throws a SOAP exception' do
          expect { response }.to raise_error(
            Proofing::Aamva::VerificationError,
            /No close tag for \/br/,
          )
        end
      end

      context 'because we have an invalid response and a non-200 status' do
        let(:response_body) { '<h1>I\'m a teapot' }
        let(:response_http_status) { 418 }

        it 'tries to parse the raw response body' do
          begin
            response
          rescue Proofing::Aamva::VerificationError
          end
        end

        it 'throws an error which complains about the invalid response' do
          expect { response }.to raise_error(
            Proofing::Aamva::VerificationError,
            /No close tag for \/h1/,
          )
        end

        it 'throws an error which complains about the HTTP error code' do
          expect { response }.to raise_error(
            Proofing::Aamva::VerificationError,
            /Unexpected status code in response: 418/,
          )
        end
      end
    end
  end
end
