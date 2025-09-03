require 'rails_helper'

RSpec.describe DocAuth::Socure::Responses::DocvResultResponse do
  let(:passport_response_body) do
    {
      status: 'complete',
      documentVerification: {
        decision: { name: 'accept', value: 'accept' },
        documentType: { type: 'passport', country: 'US' },
        documentData: {
          firstName: 'John',
          surName: 'Doe',
          dob: '1990-01-01',
        },
        reasonCodes: [],
      },
    }.to_json
  end

  let(:passport_tampering_response_body) do
    {
      status: 'complete',
      documentVerification: {
        decision: { name: 'reject', value: 'reject' },
        documentType: { type: 'passport', country: 'US' },
        documentData: {
          firstName: 'John',
          surName: 'Doe',
          dob: '1990-01-01',
        },
        reasonCodes: ['R810', 'R820'],
      },
    }.to_json
  end

  let(:state_id_response_body) do
    {
      status: 'complete',
      documentVerification: {
        decision: { name: 'accept', value: 'accept' },
        documentType: { type: 'drivers_license', state: 'CA' },
        documentData: {
          firstName: 'Jane',
          surName: 'Smith',
          dob: '1985-05-15',
        },
        reasonCodes: [],
      },
    }.to_json
  end

  let(:passport_http_response) do
    instance_double(Faraday::Response, body: passport_response_body)
  end

  let(:passport_tampering_http_response) do
    instance_double(Faraday::Response, body: passport_tampering_response_body)
  end

  let(:state_id_http_response) do
    instance_double(Faraday::Response, body: state_id_response_body)
  end

  describe 'passport analytics events' do
    let(:analytics) { instance_double(Analytics) }

    before do
      allow(Analytics).to receive(:new).and_return(analytics)
      allow(analytics).to receive(:passport_validation)
      allow(analytics).to receive(:passport_success)
      allow(analytics).to receive(:passport_tampering_detected)
    end

    context 'with successful passport validation' do
      let(:response) do
        described_class.new(
          http_response: passport_http_response,
          passport_requested: true,
        )
      end

      it 'logs passport_validation event with correct parameters' do
        response.extra_attributes

        expect(analytics).to have_received(:passport_validation).at_least(:once).with(
          vendor: 'Socure',
          success: true,
          is_passport: true,
          tampering_detected: false,
          reason_codes: [],
        )
      end

      it 'logs passport_success event' do
        response.extra_attributes

        expect(analytics).to have_received(:passport_success).at_least(:once).with(
          vendor: 'Socure',
        )
      end

      it 'does not log tampering event' do
        response.extra_attributes

        expect(analytics).not_to have_received(:passport_tampering_detected)
      end
    end

    context 'with passport tampering failure' do
      let(:response) do
        described_class.new(
          http_response: passport_tampering_http_response,
          passport_requested: true,
        )
      end

      it 'logs passport_validation event with tampering detected' do
        response.extra_attributes

        expect(analytics).to have_received(:passport_validation).at_least(:once).with(
          vendor: 'Socure',
          success: false,
          is_passport: true,
          tampering_detected: true,
          reason_codes: ['R810', 'R820'],
        )
      end

      it 'logs passport_tampering_detected event' do
        response.extra_attributes

        expect(analytics).to have_received(:passport_tampering_detected).at_least(:once).with(
          vendor: 'Socure',
          document_type: 'passport',
          alert_names: ['R810', 'R820'],
        )
      end

      it 'does not log passport_success event' do
        response.extra_attributes

        expect(analytics).not_to have_received(:passport_success)
      end
    end

    context 'with non-passport document' do
      let(:response) do
        described_class.new(
          http_response: state_id_http_response,
          passport_requested: false,
        )
      end

      it 'does not log any passport events' do
        response.extra_attributes

        expect(analytics).not_to have_received(:passport_validation)
        expect(analytics).not_to have_received(:passport_success)
        expect(analytics).not_to have_received(:passport_tampering_detected)
      end
    end
  end
end
