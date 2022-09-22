require 'rails_helper'

describe Proofing::Aamva::Request::VerificationRequest do
  let(:applicant) do
    applicant = Proofing::Aamva::Applicant.from_proofer_applicant(
      uuid: '1234-abcd-efgh',
      first_name: 'Testy',
      last_name: 'McTesterson',
      dob: '10/29/1942',
      address1: '123 Sunnyside way',
      city: 'Sterling',
      state: 'VA',
      zipcode: '20176-1234',
    )
    applicant.state_id_data.merge!(
      state_id_number: '123456789',
      state_id_jurisdiction: 'CA',
      state_id_type: 'drivers_license',
    )
    applicant
  end
  let(:auth_token) { 'KEYKEYKEY' }
  let(:transaction_id) { '1234-abcd-efgh' }
  let(:config) { AamvaFixtures.example_config }

  subject do
    described_class.new(
      applicant: applicant,
      session_id: transaction_id,
      auth_token: auth_token,
      config: config,
    )
  end

  describe '#body' do
    it 'should be a request body' do
      expect(subject.body).to eq(AamvaFixtures.verification_request)
    end

    it 'should escape XML in applicant data' do
      applicant.first_name = '<foo></bar>'

      expect(subject.body).to_not include('<foo></bar>')
      expect(subject.body).to include('&lt;foo&gt;&lt;/bar&gt;')
    end
  end

  describe '#headers' do
    it 'should return valid SOAP headers' do
      expect(subject.headers).to eq(
        'SOAPAction' =>
          '"http://aamva.org/dldv/wsdl/2.1/IDLDVService21/VerifyDriverLicenseData"',
        'Content-Type' => 'application/soap+xml;charset=UTF-8',
        'Content-Length' => subject.body.length.to_s,
      )
    end
  end

  describe '#url' do
    it 'should be the AAMVA verification url from the params' do
      expect(subject.url).to eq(config.verification_url)
    end
  end

  describe '#send' do
    context 'when the request is successful' do
      it 'returns a response object' do
        stub_request(:post, config.verification_url).
          to_return(body: AamvaFixtures.verification_response, status: 200)

        result = subject.send

        expect(result.success?).to eq(true)
      end
    end

    # rubocop:disable Layout/LineLength
    context 'when the request times out' do
      it 'raises an error' do
        stub_request(:post, config.verification_url).
          to_timeout

        expect { subject.send }.to raise_error(
          ::Proofing::TimeoutError,
          'AAMVA raised Faraday::ConnectionFailed waiting for verification response: execution expired',
        )
      end
    end
    # rubocop:enable Layout/LineLength

    context 'when the connection fails' do
      it 'raises an error' do
        stub_request(:post, config.verification_url).
          to_raise(Faraday::ConnectionFailed.new('error'))

        expect { subject.send }.to raise_error(
          ::Proofing::TimeoutError,
          'AAMVA raised Faraday::ConnectionFailed waiting for verification response: error',
        )
      end
    end
  end
end
