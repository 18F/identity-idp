require 'rails_helper'

RSpec.describe DocAuth::Acuant::Requests::CreateDocumentRequest do
  describe '#fetch' do
    let(:assure_id_url) { 'https://acuant.assureid.example.com' }
    let(:assure_id_subscription_id) { '1234567' }
    let(:image_source) { DocAuth::ImageSources::UNKNOWN }
    let(:cropping_mode) { DocAuth::Acuant::CroppingModes::ALWAYS }
    let(:sensor_type) { DocAuth::Acuant::SensorTypes::UNKNOWN }

    let(:url) { URI.join(assure_id_url, '/AssureIDService/Document/Instance') }
    let(:request_body) do
      {
        AuthenticationSensitivity: 0,
        ClassificationMode: 0,
        Device: {
          HasContactlessChipReader: false,
          HasMagneticStripeReader: false,
          SerialNumber: 'xxxxx',
          Type: {
            Manufacturer: 'Login.gov',
            Model: 'Doc Auth 1.0',
            SensorType: sensor_type,
          },
        },
        ImageCroppingExpectedSize: '1',
        ImageCroppingMode: cropping_mode,
        ManualDocumentType: nil,
        ProcessMode: 0,
        SubscriptionId: assure_id_subscription_id,
      }.to_json
    end
    let(:response_body) do
      AcuantFixtures.create_document_response
    end

    let(:config) do
      DocAuth::Acuant::Config.new(
        assure_id_url:,
        assure_id_subscription_id:,
      )
    end

    context 'acuant sdk image source' do
      let(:image_source) { DocAuth::ImageSources::ACUANT_SDK }
      let(:cropping_mode) { DocAuth::Acuant::CroppingModes::NONE }
      let(:sensor_type) { DocAuth::Acuant::SensorTypes::MOBILE }

      it 'sends a well formed request and returns a response with the instance ID' do
        request_stub = stub_request(:post, url).with(
          body: request_body,
        ).to_return(
          body: response_body,
        )

        response = described_class.new(config:, image_source:).fetch

        expect(response.success?).to eq(true)
        expect(response.errors).to eq({})
        expect(response.exception).to be_nil
        expect(response.instance_id).to eq('this-is-a-test-instance-id') # instance ID from fixture
        expect(request_stub).to have_been_requested
      end
    end

    context 'upload image source' do
      let(:image_source) { DocAuth::ImageSources::UNKNOWN }
      let(:cropping_mode) { DocAuth::Acuant::CroppingModes::ALWAYS }
      let(:sensor_type) { DocAuth::Acuant::SensorTypes::UNKNOWN }

      it 'sends a well formed request and returns a response with the instance ID' do
        request_stub = stub_request(:post, url).with(
          body: request_body,
        ).to_return(
          body: response_body,
        )

        response = described_class.new(config:, image_source:).fetch

        expect(response.success?).to eq(true)
        expect(response.errors).to eq({})
        expect(response.exception).to be_nil
        expect(response.instance_id).to eq('this-is-a-test-instance-id') # instance ID from fixture
        expect(request_stub).to have_been_requested
      end
    end
  end
end
