require 'rails_helper'

RSpec.describe DocAuth::Acuant::Responses::GetResultsResponse do
  let(:config) do
    DocAuth::Acuant::Config.new
  end
  subject(:response) { described_class.new(http_response, config) }

  context 'with a successful result' do
    let(:http_response) do
      instance_double(
        Faraday::Response,
        body: AcuantFixtures.get_results_response_success,
      )
    end
    let(:raw_alerts) { JSON.parse(AcuantFixtures.get_results_response_success)['Alerts'] }
    let(:raw_regions) { JSON.parse(AcuantFixtures.get_results_response_success)['Regions'] }

    it 'returns a successful response with no errors' do
      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to be_nil

      response_hash = response.to_h
      expected_hash = {
        success: true,
        errors: {},
        attention_with_barcode: false,
        exception: nil,
        billed: true,
        vendor: 'Acuant',
        doc_auth_result: 'Passed',
        processed_alerts: a_hash_including(
          failed: all(a_hash_including(:name, :result)),
          passed: all(a_hash_including(:name, :result)),
        ),
        log_alert_results: a_hash_including('2d_barcode_content': { no_side: 'Passed' }),
        image_metrics: a_hash_including(:back, :front),
        alert_failure_count: 2,
        tamper_result: 'Passed',
      }

      processed_alerts = response_hash[:processed_alerts]
      expected_alerts = {
        passed:
          a_collection_including(
            a_hash_including(side: :front, region: 'Flag Pattern'),
            a_hash_including(side: :front, region: 'Lower Data Labels Right'),
          ),
      }

      expect(response_hash).to match(expected_hash)
      expect(processed_alerts).to include(expected_alerts)
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
        dob: '1984-04-01',
        state_id_expiration: '2022-10-24',
        state_id_issued: '2014-10-24',
        state_id_number: 'DOE-84-1165',
        state_id_jurisdiction: 'ND',
        state_id_type: 'state_id_card',
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
        [{ Result: 5, Key: '2D Barcode Read' },
         { Result: 1, Key: 'Birth Date Valid' }]
      end

      it 'is a successful result' do
        expect(response.success?).to eq(true)
      end
    end

    context 'when there are other unsuccessful alerts' do
      let(:alerts) do
        [{ Result: 5, Key: '2D Barcode Read' },
         { Result: 4, Key: 'Birth Date Crosscheck' }]
      end

      it 'is not a successful result' do
        expect(response.success?).to eq(false)
      end
    end
  end

  context 'when there are errors and still parsed PII fields' do
    let(:http_response) do
      instance_double(
        Faraday::Response,
        body: AcuantFixtures.get_results_response_expired,
      )
    end

    it 'is not sucessful, has errors, and still has pii_from_doc' do
      aggregate_failures do
        expect(response.success?).to eq(false)

        expect(response.errors).to eq(
          general: [DocAuth::Errors::DOCUMENT_EXPIRED_CHECK],
          front: [DocAuth::Errors::FALLBACK_FIELD_LEVEL],
          back: [DocAuth::Errors::FALLBACK_FIELD_LEVEL],
          hints: true,
        )

        expect(response.pii_from_doc).to include(
          first_name: 'FAKEY',
          last_name: 'MCFAKERSON',
          state_id_expiration: '2021-01-14',
          state_id_issued: '2017-06-01',
        )
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
    let(:parsed_response_body) { JSON.parse(AcuantFixtures.get_results_response_failure) }

    it 'returns an unsuccessful response with errors' do
      expect(response.success?).to eq(false)
      expect(response.errors).to eq(
        general: [DocAuth::Errors::ID_NOT_RECOGNIZED],
        front: [DocAuth::Errors::FALLBACK_FIELD_LEVEL],
        back: [DocAuth::Errors::FALLBACK_FIELD_LEVEL],
        hints: true,
      )
      expect(response.to_h[:log_alert_results]).to eq(
        document_classification: { no_side: 'Failed' },
      )
      expect(response.exception).to be_nil
      expect(response.result_code).to eq(DocAuth::Acuant::ResultCodes::UNKNOWN)
      expect(response.result_code.billed?).to eq(false)
    end

    context 'when visiual_pattern passes and fails' do
      let(:http_response) do
        [1, 2].each do |index|
          parsed_response_body['Alerts'] << {
            Key: 'Visible Pattern',
            Name: 'Visible Pattern',
            RegionReferences: [],
            Result: index,
          }
        end

        instance_double(
          Faraday::Response,
          body: parsed_response_body.to_json,
        )
      end

      it 'returns log_alert_results for visible_pattern with multiple results comma separated' do
        expect(response.to_h[:processed_alerts]).to eq(
          passed: [{ name: 'Visible Pattern', result: 'Passed' }],
          failed:
            [{ name: 'Document Classification',
               result: 'Failed' },
             { name: 'Visible Pattern',
               result: 'Failed' }],
        )

        expect(response.to_h[:log_alert_results]).to eq(
          { visible_pattern: { no_side: 'Failed' },
            document_classification: { no_side: 'Failed' } },
        )
      end
    end

    context 'when with an acuant error message' do
      let(:http_response) do
        parsed_response_body['Alerts'].first['Disposition'] = 'This message does not have a key'
        instance_double(
          Faraday::Response,
          body: parsed_response_body.to_json,
        )
      end

      it 'returns the untranslated error' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          general: [DocAuth::Errors::ID_NOT_RECOGNIZED],
          front: [DocAuth::Errors::FALLBACK_FIELD_LEVEL],
          back: [DocAuth::Errors::FALLBACK_FIELD_LEVEL],
          hints: true,
        )
        expect(response.exception).to be_nil
      end
    end

    context 'when multiple alerts have the same friendly error' do
      let(:http_response) do
        parsed_response_body['Alerts'].first['Disposition'] = 'This message does not have a key'
        parsed_response_body['Alerts'][1] = parsed_response_body['Alerts'].first
        instance_double(
          Faraday::Response,
          body: parsed_response_body.to_json,
        )
      end

      it 'only returns one copy of the each error' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          general: [DocAuth::Errors::GENERAL_ERROR_NO_LIVENESS],
          front: [DocAuth::Errors::FALLBACK_FIELD_LEVEL],
          back: [DocAuth::Errors::FALLBACK_FIELD_LEVEL],
          hints: true,
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
              { Result: 1, Key: 'Birth Date Valid' },
              { Result: 2, Key: 'Document Classification' },
            ],
          }.to_json,
        )
      end

      it 'does not return errors for alerts with success result codes' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          general: [DocAuth::Errors::ID_NOT_RECOGNIZED],
          front: [DocAuth::Errors::FALLBACK_FIELD_LEVEL],
          back: [DocAuth::Errors::FALLBACK_FIELD_LEVEL],
          hints: true,
        )
        expect(response.exception).to be_nil
      end
    end

    # leaving this as a sanity check, error_generator_spec has these tests now
    context 'when front image HDPI is too low' do
      let(:http_response) do
        parsed_response_body['Images'].first['HorizontalResolution'] = 250
        instance_double(
          Faraday::Response,
          body: parsed_response_body.to_json,
        )
      end

      it 'returns an unsuccessful response with front DPI error' do
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          general: [DocAuth::Errors::DPI_LOW_ONE_SIDE],
          front: [DocAuth::Errors::DPI_LOW_FIELD],
          hints: false,
        )
        expect(response.exception).to be_nil
        expect(response.result_code).to eq(DocAuth::Acuant::ResultCodes::UNKNOWN)
        expect(response.result_code.billed?).to eq(false)
      end
    end
  end

  describe '#attention_with_barcode?' do
    let(:result) { DocAuth::Acuant::ResultCodes::PASSED.code }
    let(:alerts) { [] }
    let(:http_response) do
      instance_double(
        Faraday::Response,
        body: { Result: result, Alerts: alerts }.to_json,
      )
    end

    subject(:attention_with_barcode) { response.attention_with_barcode? }

    it { expect(attention_with_barcode).to eq(false) }

    context 'with multiple errors including barcode attention' do
      let(:result) { DocAuth::Acuant::ResultCodes::ATTENTION.code }
      let(:alerts) do
        [
          { Result: DocAuth::Acuant::ResultCodes::ATTENTION.code, Key: '2D Barcode Read' },
          { Result: DocAuth::Acuant::ResultCodes::ATTENTION.code, Key: 'Birth Date Crosscheck' },
        ]
      end

      it { expect(attention_with_barcode).to eq(false) }
    end

    context 'with single barcode attention error' do
      let(:result) { DocAuth::Acuant::ResultCodes::ATTENTION.code }
      let(:alerts) do
        [
          { Result: DocAuth::Acuant::ResultCodes::ATTENTION.code, Key: '2D Barcode Read' },
          { Result: DocAuth::Acuant::ResultCodes::PASSED.code, Key: 'Birth Date Valid' },
        ]
      end

      it { expect(attention_with_barcode).to eq(true) }
    end
  end
end
