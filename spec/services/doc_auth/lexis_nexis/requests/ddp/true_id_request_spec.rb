require 'rails_helper'

RSpec.describe DocAuth::LexisNexis::Requests::Ddp::TrueIdRequest do
  let(:front_image) { 'front_image_data' }
  let(:back_image) { 'back_image_data' }
  let(:selfie_image) { 'selfie_image_data' }
  let(:passport_image) { 'passport_image_data' }
  let(:liveness_checking_required) { false }
  let(:document_type_requested) { DocAuth::LexisNexis::DocumentTypes::DRIVERS_LICENSE }
  let(:applicant) do
    {
      email: 'person.name@email.test',
      uuid_prefix: 'test_prefix',
      uuid: 'test_uuid_12345',
      front_image: front_image,
      back_image: back_image,
      selfie_image: selfie_image,
      passport_image: passport_image,
      document_type_requested: document_type_requested,
      liveness_checking_required: liveness_checking_required,
    }
  end

  let(:config) do
    Proofing::LexisNexis::Config.new(
      api_key: 'test_api_key',
      base_url: 'https://example.com',
      org_id: 'test_org_id',
    )
  end

  subject { described_class.new(config: config, applicant: applicant) }

  before do
    allow(IdentityConfig.store).to receive(:lexisnexis_trueid_ddp_liveness_policy)
      .and_return('test_liveness_policy')
    allow(IdentityConfig.store).to receive(:lexisnexis_trueid_ddp_noliveness_policy)
      .and_return('test_noliveness_policy')
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_timeout)
      .and_return(30.0)
  end

  describe '#send_request' do
    before do
      stub_request(:post, 'https://example.com/authentication/v1/trueid/')
        .to_return(
          status: 200,
          body: { 'request_result' => 'success', 'review_status' => 'pass' }.to_json,
        )
    end

    it 'sends a POST request to the trueid endpoint' do
      subject.send_request

      expect(WebMock).to have_requested(:post, 'https://example.com/authentication/v1/trueid/')
    end

    it 'includes correct headers' do
      subject.send_request

      expect(WebMock).to have_requested(:post, 'https://example.com/authentication/v1/trueid/')
        .with(headers: {
          'Content-Type' => 'application/json',
          'x-org-id' => 'test_org_id',
          'x-api-key' => 'test_api_key',
        })
    end

    it 'includes images with correct key format' do
      subject.send_request

      expect(WebMock).to have_requested(:post, 'https://example.com/authentication/v1/trueid/')
        .with { |req|
          body = JSON.parse(req.body)
          body['Trueid.image_data.white_front'] == Base64.strict_encode64(front_image) &&
            body['Trueid.image_data.white_back'] == Base64.strict_encode64(back_image)
        }
    end

    it 'includes required request fields' do
      subject.send_request

      expect(WebMock).to have_requested(:post, 'https://example.com/authentication/v1/trueid/')
        .with { |req|
          body = JSON.parse(req.body)
          body['account_email'] == 'person.name@email.test' &&
            body['service_type'] == 'basic' &&
            body['local_attrib_1'] == 'test_prefix' &&
            body['local_attrib_3'] == 'test_uuid_12345' &&
            body['auth_method'] == 'trueid'
        }
    end

    context 'when liveness checking is required' do
      let(:liveness_checking_required) { true }

      it 'includes selfie image and uses liveness policy' do
        subject.send_request

        expect(WebMock).to have_requested(:post, 'https://example.com/authentication/v1/trueid/')
          .with { |req|
            body = JSON.parse(req.body)
            body['Trueid.image_data.selfie'] == Base64.strict_encode64(selfie_image) &&
              body['policy'] == 'test_liveness_policy'
          }
      end
    end

    context 'when liveness checking is not required' do
      let(:liveness_checking_required) { false }

      it 'uses the noliveness policy' do
        subject.send_request

        expect(WebMock).to have_requested(:post, 'https://example.com/authentication/v1/trueid/')
          .with { |req|
            body = JSON.parse(req.body)
            body['policy'] == 'test_noliveness_policy'
          }
      end
    end

    context 'when document type is passport' do
      let(:document_type_requested) { DocAuth::LexisNexis::DocumentTypes::PASSPORT }

      it 'uses passport image as front and excludes back image' do
        subject.send_request

        expect(WebMock).to have_requested(:post, 'https://example.com/authentication/v1/trueid/')
          .with { |req|
            body = JSON.parse(req.body)
            body['Trueid.image_data.white_front'] == Base64.strict_encode64(passport_image) &&
              body['Trueid.image_data.white_back'] == ''
          }
      end
    end

    context 'with empty optional fields' do
      let(:applicant) do
        {
          front_image: front_image,
          back_image: back_image,
          document_type_requested: document_type_requested,
          liveness_checking_required: liveness_checking_required,
        }
      end

      it 'uses empty string defaults' do
        subject.send_request

        expect(WebMock).to have_requested(:post, 'https://example.com/authentication/v1/trueid/')
          .with { |req|
            body = JSON.parse(req.body)
            body['account_email'] == '' &&
              body['local_attrib_1'] == ''
          }
      end
    end
  end

  describe 'image validation' do
    before do
      stub_request(:post, 'https://example.com/authentication/v1/trueid/')
        .to_return(
          status: 200,
          body: { 'request_result' => 'success', 'review_status' => 'pass' }.to_json,
        )
    end

    context 'when front_image is nil' do
      let(:applicant) do
        {
          front_image: nil,
          back_image: back_image,
          document_type_requested: DocAuth::LexisNexis::DocumentTypes::DRIVERS_LICENSE,
          liveness_checking_required: false,
        }
      end

      it 'raises ArgumentError' do
        expect { subject.send_request }.to raise_error(ArgumentError, 'front_image is required')
      end
    end

    context 'when back_image is nil' do
      let(:applicant) do
        {
          front_image: front_image,
          back_image: nil,
          document_type_requested: DocAuth::LexisNexis::DocumentTypes::DRIVERS_LICENSE,
          liveness_checking_required: false,
        }
      end

      it 'raises ArgumentError' do
        expect { subject.send_request }.to raise_error(ArgumentError, 'back_image is required')
      end
    end

    context 'when passport_image is nil for passport documents' do
      let(:applicant) do
        {
          front_image: front_image,
          back_image: back_image,
          passport_image: nil,
          document_type_requested: DocAuth::LexisNexis::DocumentTypes::PASSPORT,
          liveness_checking_required: false,
        }
      end

      it 'raises ArgumentError' do
        expect { subject.send_request }.to raise_error(
          ArgumentError,
          'passport_image is required for passport documents',
        )
      end
    end

    context 'when selfie_image is nil with liveness checking' do
      let(:applicant) do
        {
          front_image: front_image,
          back_image: back_image,
          selfie_image: nil,
          document_type_requested: DocAuth::LexisNexis::DocumentTypes::DRIVERS_LICENSE,
          liveness_checking_required: true,
        }
      end

      it 'raises ArgumentError' do
        expect { subject.send_request }.to raise_error(
          ArgumentError,
          'selfie_image is required when liveness checking is enabled',
        )
      end
    end
  end
end
