require 'rails_helper'

describe DocAuth::Acuant::Responses::GetResultsResponse do
  subject(:response) { described_class.new(http_response) }

  context 'with a successful result' do
    let(:http_response) do
      instance_double(
        Faraday::Response,
        body: AcuantFixtures.get_results_response_success,
      )
    end
    let(:raw_alerts) { JSON.parse(AcuantFixtures.get_results_response_success)['Alerts'] }

    it 'returns a successful response with no errors' do
      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to be_nil
      expect(response.to_h).to eq(
        success: true,
        errors: {},
        exception: nil,
        billed: true,
        result: 'Passed',
        raw_alerts: raw_alerts,
      )
      expect(response.result_code).to eq(DocAuth::Acuant::ResultCodes::PASSED)
      expect(response.result_code.billed?).to eq(true)
    end

    it 'parsed PII from the doc' do
      # The PII from the response fixture
      expect(response.pii_from_doc).to eq(
        first_name: 'JANE',
        middle_name: nil,
        last_name: 'DOE',
        address1: '1000 E AVENUE E',
        city: 'BISMARCK',
        state: 'ND',
        zipcode: '58501',
        dob: '04/01/1984',
        state_id_number: 'DOE-84-1165',
        state_id_jurisdiction: 'ND',
        state_id_type: 'drivers_license',
      )
    end
  end

  context 'with an attention result' do
    let(:http_response) do
      instance_double(
        Faraday::Response,
        body: {
          Result: 5,
          Alerts: alerts,
        }.to_json,
      )
    end

    context 'when the only unsuccessful alert is attention barcode could not be read' do
      let(:alerts) do
        [{ Result: 5, Disposition: 'The 2D barcode could not be read' },
         { Result: 1, Disposition: 'The birth date is valid' }]
      end

      it 'is a successful result' do
        expect(response.success?).to eq(true)
      end
    end

    context 'when there are other unsuccessful alerts' do
      let(:alerts) do
        [{ Result: 5, Disposition: 'The 2D barcode could not be read' },
         { Result: 4, Disposition: 'The birth dates do not match' }]
      end

      it 'is not a successful result' do
        expect(response.success?).to eq(false)
      end
    end
  end

  context 'with a failed result' do
    let(:http_response) do
      instance_double(
        Faraday::Response,
        body: AcuantFixtures.get_results_response_failure,
      )
    end
    let(:raw_alerts) { JSON.parse(AcuantFixtures.get_results_response_success)['Alerts'] }

    subject(:response) { described_class.new(http_response) }

    it 'returns an unsuccessful response with errors' do
      expect(response.success?).to eq(false)
      expect(response.errors).to eq(
        # This is the error message for the error in the response fixture
        results: [I18n.t('friendly_errors.doc_auth.document_type_could_not_be_determined')],
      )
      expect(response.exception).to be_nil
      expect(response.result_code).to eq(DocAuth::Acuant::ResultCodes::UNKNOWN)
      expect(response.result_code.billed?).to eq(false)
    end

    context 'when a friendly error does not exist for the acuant error message' do
      let(:http_response) do
        parsed_response_body = JSON.parse(AcuantFixtures.get_results_response_failure)
        parsed_response_body['Alerts'].first['Disposition'] = 'This message does not have key'
        instance_double(
          Faraday::Response,
          body: parsed_response_body.to_json,
        )
      end

      it 'returns the general error' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          # This is the error message for the error in the response fixture
          results: [I18n.t('errors.doc_auth.general_error')],
        )
        expect(response.exception).to be_nil
      end
    end

    context 'when multiple alerts have the same friendly error' do
      let(:http_response) do
        parsed_response_body = JSON.parse(AcuantFixtures.get_results_response_failure)
        parsed_response_body['Alerts'].first['Disposition'] = 'This message does not have key'
        parsed_response_body['Alerts'][1] = parsed_response_body['Alerts'].first
        instance_double(
          Faraday::Response,
          body: parsed_response_body.to_json,
        )
      end

      it 'only returns one copy of the friendly error' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          # This is the error message for the error in the response fixture
          results: [I18n.t('errors.doc_auth.general_error')],
        )
        expect(response.exception).to be_nil
      end
    end

    context 'when there are alerts with success result codes' do
      let(:http_response) do
        instance_double(
          Faraday::Response,
          body: {
            Result: 2,
            Alerts: [
              { Result: 1, Disposition: 'The birth date is valid' },
              { Result: 2, Disposition: 'The document type could not be determined' },
            ],
          }.to_json,
        )
      end

      it 'does not return errors for alerts with success result codes' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          # This is the error message for the error in the response fixture
          results: [I18n.t('friendly_errors.doc_auth.document_type_could_not_be_determined')],
        )
        expect(response.exception).to be_nil
      end
    end
  end
end
