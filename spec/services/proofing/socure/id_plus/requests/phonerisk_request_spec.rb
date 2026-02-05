require 'rails_helper'

RSpec.describe Proofing::Socure::IdPlus::Requests::PhoneRiskRequest do
  let(:config) do
    Proofing::Socure::IdPlus::Config.new(
      user_uuid: user.uuid,
      user_email: user.email,
      api_key:,
      base_url:,
      timeout:,
    )
  end
  let(:api_key) { 'super-$ecret' }
  let(:base_url) { 'https://example.org/' }
  let(:timeout) { 5 }
  let(:user) { build(:user) }
  let(:input) do
    Proofing::Socure::IdPlus::Input.new(
      **Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.merge(
        email: 'fakey@mckfakerson.test',
      ).slice(
        *Proofing::Socure::IdPlus::Input.members,
      ),
    )
  end

  subject(:request) do
    described_class.new(config:, input:)
  end

  describe '#body' do
    it 'contains all expected values' do
      expect(JSON.parse(request.body, symbolize_names: true)).to eql(
        {
          modules: [
            'phonerisk',
          ],
          firstName: 'FAKEY',
          surName: 'MCFAKERSON',
          physicalAddress: '1 FAKE RD',
          physicalAddress2: '',
          city: 'GREAT FALLS',
          state: 'MT',
          zip: '59010-1234',
          country: 'US',
          customerUserId: user.uuid,
          email: 'fakey@mckfakerson.test',
          mobileNumber: Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE[:phone],
          returnSignals: true,
        },
      )
    end
  end

  describe '#headers' do
    it 'includes appropriate Content-Type header' do
      expect(request.headers).to include('Content-Type' => 'application/json')
    end

    it 'includes appropriate Authorization header' do
      expect(request.headers).to include('Authorization' => "SocureApiKey #{api_key}")
    end
  end

  describe '#send_request' do
    let(:response_body) do
      {
        referenceId: 'some-reference-id',
        namePhoneCorrelation: {
          reasonCodes: [
            'I123',
            'R567',
            'R890',
          ],
          score: 0.99,
        },
        phoneRisk: {
          reasonCodes: [
            'I123',
            'R567',
          ],
          score: 0.01,
          signals: {
            phone: {},
          },
        },
        customerProfile: {
          customerUserId: user.uuid,
        },
      }
    end

    before do
      stub_request(:post, 'https://example.org/api/3.0/EmailAuthScore')
        .to_return(
          headers: {
            'Content-Type' => 'application/json',
          },
          body: JSON.generate(response_body),
        )
    end

    it 'includes API key' do
      request.send_request

      expect(WebMock).to have_requested(
        :post, 'https://example.org/api/3.0/EmailAuthScore'
      ).with(headers: { 'Authorization' => "SocureApiKey #{api_key}" })
    end

    it 'includes JSON serialized body' do
      request.send_request

      expect(WebMock).to have_requested(
        :post, 'https://example.org/api/3.0/EmailAuthScore'
      ).with(body: request.body)
    end

    context 'when service returns HTTP 200 response' do
      it 'method returns a Proofing::Socure::IdPlus::Response' do
        res = request.send_request
        expect(res).to be_a(Proofing::Socure::IdPlus::Responses::PhoneRiskResponse)
      end

      it 'response has phonerisk data' do
        res = request.send_request.to_h

        expect(res.dig(:phonerisk, :reason_codes).keys).to eq(['I123', 'R567'])
        expect(res.dig(:phonerisk, :score)).to eq(0.01)
        expect(res.dig(:phonerisk, :signals, 'phone')).to eq({})
        expect(res.dig(:name_phone_correlation, :reason_codes).keys).to eq(['I123', 'R567', 'R890'])
        expect(res.dig(:name_phone_correlation, :score)).to eq(0.99)
      end

      it 'response has customer_user_id' do
        res = request.send_request
        expect(res.customer_user_id).to eql(user.uuid)
      end
    end

    context 'when service returns an HTTP 400 response' do
      before do
        stub_request(:post, 'https://example.org/api/3.0/EmailAuthScore')
          .to_return(
            status: 400,
            headers: {
              'Content-Type' => 'application/json',
            },
            body: JSON.generate(
              {
                status: 'Error',
                referenceId: 'a-big-unique-reference-id',
                data: {
                  parameters: ['firstName'],
                },
                msg: 'Request-specific error message goes here',
              },
            ),
          )
      end

      it 'raises Request::Error' do
        expect do
          request.send_request
        end.to raise_error(
          Proofing::Socure::IdPlus::Request::Error,
          'Request-specific error message goes here (400)',
        )
      end

      it 'includes reference_id on Request::Error' do
        expect do
          request.send_request
        end.to raise_error(
          Proofing::Socure::IdPlus::Request::Error,
        ) do |err|
          expect(err.reference_id).to eql('a-big-unique-reference-id')
        end
      end
    end

    context 'when service returns an HTTP 401 reponse' do
      before do
        stub_request(:post, 'https://example.org/api/3.0/EmailAuthScore')
          .to_return(
            status: 401,
            headers: {
              'Content-Type' => 'application/json',
            },
            body: JSON.generate(
              {
                status: 'Error',
                referenceId: 'a-big-unique-reference-id',
                msg: 'Request-specific error message goes here',
              },
            ),
          )
      end

      it 'raises Request::Error' do
        expect do
          request.send_request
        end.to raise_error(
          Proofing::Socure::IdPlus::Request::Error,
          'Request-specific error message goes here (401)',
        )
      end
    end

    context 'when service returns weird HTTP 500 response' do
      before do
        stub_request(:post, 'https://example.org/api/3.0/EmailAuthScore')
          .to_return(
            status: 500,
            body: 'It works!',
          )
      end

      it 'raises Request::Error' do
        expect do
          request.send_request
        end.to raise_error(Proofing::Socure::IdPlus::Request::Error)
      end
    end

    context 'when request times out' do
      before do
        stub_request(:post, 'https://example.org/api/3.0/EmailAuthScore')
          .to_timeout
      end

      it 'raises a ProofingTimeoutError' do
        expect { request.send_request }.to raise_error Proofing::TimeoutError
      end
    end

    context 'when connection is reset' do
      before do
        stub_request(:post, 'https://example.org/api/3.0/EmailAuthScore')
          .to_raise(Errno::ECONNRESET)
      end

      it 'raises a Request::Error' do
        expect { request.send_request }.to raise_error Proofing::Socure::IdPlus::Request::Error
      end
    end
  end
end
