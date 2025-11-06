require 'rails_helper'

RSpec.describe DocumentCaptureSession do
  let(:doc_auth_response) do
    DocAuth::Response.new(
      success: true,
      pii_from_doc: Pii::StateId.new(
        first_name: 'Testy',
        last_name: 'Testy',
        middle_name: nil,
        name_suffix: nil,
        address1: '123 ABC AVE',
        address2: nil,
        city: 'ANYTOWN',
        state: 'MD',
        dob: '1986-07-01',
        sex: nil,
        height: nil,
        weight: nil,
        eye_color: nil,
        state_id_expiration: '2099-10-15',
        state_id_issued: '2016-10-15',
        state_id_jurisdiction: 'MD',
        state_id_number: 'M555555555555',
        document_type_received: 'drivers_license',
        zipcode: '12345',
        issuing_country_code: 'USA',
      ),
      extra: {
        doc_auth_result: 'Passed',
      },
    )
  end

  let(:failed_doc_auth_response) { DocAuth::Response.new(success: false) }
  let(:mrz_response) { DocAuth::Response.new(success: true) }
  let(:aamva_response) { DocAuth::Response.new(success: true) }

  before do
    allow(doc_auth_response).to receive(:doc_auth_success?).and_return(true)
    allow(doc_auth_response).to receive(:selfie_status).and_return(:success)
  end

  context 'validates passport status' do
    context 'passport_status is invalid' do
      it 'throws error' do
        expect { create(:document_capture_session, passport_status: 'invalid') }
          .to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'passport_status is requested' do
      it 'does not throw error' do
        expect { create(:document_capture_session, passport_status: 'requested') }
          .not_to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'passport_status is nil' do
      it 'does not throws error' do
        expect { create(:document_capture_session, passport_status: nil) }
          .not_to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe '#store_result_from_response' do
    let(:attempt) { 1 }

    it 'generates a result ID stores the result encrypted in redis' do
      record = DocumentCaptureSession.new

      record.store_result_from_response(doc_auth_response, attempt:)

      result_id = record.result_id
      key = EncryptedRedisStructStorage.key(result_id, type: DocumentCaptureSessionResult)
      data = REDIS_POOL.with { |client| client.get(key) }
      expect(data).to be_a(String)
      expect(data).to_not include('Testy')
      expect(data).to_not include('Testerson')
      expect(record.ocr_confirmation_pending).to eq(false)
    end

    context 'with attention with barcode response' do
      before { allow(doc_auth_response).to receive(:attention_with_barcode?).and_return(true) }

      it 'sets record as pending ocr confirmation' do
        record = DocumentCaptureSession.new
        record.store_result_from_response(doc_auth_response, attempt:)
        expect(record.ocr_confirmation_pending).to eq(true)
      end
    end

    context 'when all fields are passed in' do
      let(:current_time) { Time.zone.now }
      let(:document_capture_session) { DocumentCaptureSession.new(result_id: SecureRandom.uuid) }

      before do
        freeze_time
        travel_to(current_time) do
          document_capture_session.store_result_from_response(
            doc_auth_response, mrz_response:, aamva_response:, attempt: 3
          )
        end
      end

      it 'stores the results' do
        expect(document_capture_session.load_result).to have_attributes(
          success: true,
          pii: doc_auth_response.pii_from_doc.to_h,
          captured_at: current_time,
          attention_with_barcode: false,
          doc_auth_success: true,
          selfie_status: :success,
          errors: {},
          mrz_status: :pass,
          aamva_status: :passed,
          attempt: 3,
        )
      end
    end

    context 'when aamva response is passed in' do
      let(:document_capture_session) { DocumentCaptureSession.new(result_id: SecureRandom.uuid) }

      before do
        document_capture_session.store_result_from_response(
          doc_auth_response,
          attempt: 1,
          aamva_response:,
        )
      end

      context 'when the aamva response is successful' do
        let(:aamva_response) { DocAuth::Response.new(success: true) }

        it 'stores aamva_status as :passed' do
          expect(document_capture_session.load_result).to have_attributes(aamva_status: :passed)
        end
      end

      context 'when the aamva response is unsuccessful' do
        let(:aamva_response) { DocAuth::Response.new(success: false) }

        it 'stores aamva_status as :failed' do
          expect(document_capture_session.load_result).to have_attributes(aamva_status: :failed)
        end
      end

      context 'when the aamva response is nil' do
        let(:aamva_response) { nil }

        it 'stores aamva_status as :not_processed' do
          expect(document_capture_session.load_result).to have_attributes(
            aamva_status: :not_processed,
          )
        end
      end
    end
  end

  describe '#load_result' do
    it 'loads the previously stored result' do
      record = DocumentCaptureSession.new
      record.store_result_from_response(doc_auth_response, attempt: 1)
      result = record.load_result

      expect(result.success?).to eq(doc_auth_response.success?)
      expect(result.pii).to eq(doc_auth_response.pii_from_doc.to_h.deep_symbolize_keys)
    end

    it 'returns nil if the previously stored result does not exist or expired' do
      record = DocumentCaptureSession.new
      result = record.load_result

      expect(result).to eq(nil)
    end
  end

  describe '#expired?' do
    before do
      allow(IdentityConfig.store).to receive(:doc_capture_request_valid_for_minutes).and_return(15)
    end

    context 'requested_at is nil' do
      it 'returns true' do
        record = DocumentCaptureSession.new

        expect(record.expired?).to eq(true)
      end
    end

    context 'requested_at is datetime' do
      it 'returns true if expired' do
        record = DocumentCaptureSession.new(requested_at: 1.hour.ago)

        expect(record.expired?).to eq(true)
      end

      it 'returns false if not expired' do
        record = DocumentCaptureSession.new(requested_at: 1.minute.ago)

        expect(record.expired?).to eq(false)
      end
    end
  end

  describe '#store_failed_auth_data' do
    let(:current_time) { Time.zone.now }
    let(:document_capture_session) { DocumentCaptureSession.new(result_id: SecureRandom.uuid) }

    context 'when all required fields are passed in' do
      before do
        freeze_time
        travel_to(current_time) do
          document_capture_session.store_failed_auth_data(
            front_image_fingerprint: 'fingerprint-front1',
            back_image_fingerprint: 'fingerprint-back1',
            passport_image_fingerprint: 'fingerprint-passport1',
            selfie_image_fingerprint: 'fingerprint-selfie1',
            doc_auth_success: false,
            selfie_status: :fail,
            attempt: 1,
          )
        end
      end

      it 'stores the failed data results' do
        expect(document_capture_session.load_result).to have_attributes(
          success: false,
          captured_at: current_time,
          doc_auth_success: false,
          selfie_status: :fail,
          failed_front_image_fingerprints: ['fingerprint-front1'],
          failed_back_image_fingerprints: ['fingerprint-back1'],
          failed_passport_image_fingerprints: ['fingerprint-passport1'],
          failed_selfie_image_fingerprints: ['fingerprint-selfie1'],
          errors: nil,
          mrz_status: :not_processed,
          attempt: 1,
        )
      end
    end

    context 'when all fields are passed in' do
      before do
        freeze_time
        travel_to(current_time) do
          document_capture_session.store_failed_auth_data(
            front_image_fingerprint: 'fingerprint-front1',
            back_image_fingerprint: 'fingerprint-back1',
            passport_image_fingerprint: 'fingerprint-passport1',
            selfie_image_fingerprint: 'fingerprint-selfie1',
            doc_auth_success: false,
            selfie_status: :fail,
            errors: [error: 'I am error'],
            mrz_status: :not_processed,
            aamva_status: :failed,
            attempt: 3,
          )
        end
      end

      it 'stores the failed data results' do
        expect(document_capture_session.load_result).to have_attributes(
          success: false,
          captured_at: current_time,
          doc_auth_success: false,
          selfie_status: :fail,
          failed_front_image_fingerprints: ['fingerprint-front1'],
          failed_back_image_fingerprints: ['fingerprint-back1'],
          failed_passport_image_fingerprints: ['fingerprint-passport1'],
          failed_selfie_image_fingerprints: ['fingerprint-selfie1'],
          errors: [error: 'I am error'],
          mrz_status: :not_processed,
          aamva_status: :failed,
          attempt: 3,
        )
      end
    end

    context 'when multiple calls are made' do
      before do
        document_capture_session.store_failed_auth_data(
          front_image_fingerprint: 'fingerprint-front1',
          back_image_fingerprint: 'fingerprint-back1',
          passport_image_fingerprint: 'fingerprint-passport1',
          selfie_image_fingerprint: 'fingerprint-selfie1',
          doc_auth_success: false,
          selfie_status: :fail,
          attempt: 1,
        )
        document_capture_session.store_failed_auth_data(
          front_image_fingerprint: 'fingerprint-front2',
          back_image_fingerprint: 'fingerprint-back2',
          passport_image_fingerprint: 'fingerprint-passport2',
          selfie_image_fingerprint: 'fingerprint-selfie2',
          doc_auth_success: false,
          selfie_status: :fail,
          attempt: 2,
        )
      end

      it 'stores multiple images in the failed data results' do
        expect(document_capture_session.load_result).to have_attributes(
          failed_front_image_fingerprints: ['fingerprint-front1', 'fingerprint-front2'],
          failed_back_image_fingerprints: ['fingerprint-back1', 'fingerprint-back2'],
          failed_passport_image_fingerprints: ['fingerprint-passport1', 'fingerprint-passport2'],
          failed_selfie_image_fingerprints: ['fingerprint-selfie1', 'fingerprint-selfie2'],
          attempt: 2,
        )
      end
    end

    context 'when selfie is successful' do
      before do
        document_capture_session.store_failed_auth_data(
          front_image_fingerprint: 'fingerprint1',
          back_image_fingerprint: 'fingerprint2',
          passport_image_fingerprint: nil,
          selfie_image_fingerprint: 'fingerprint3',
          doc_auth_success: false,
          selfie_status: :pass,
          attempt: 3,
        )
      end

      it 'does not add selfie to failed image fingerprints' do
        expect(document_capture_session.load_result).to have_attributes(
          failed_front_image_fingerprints: ['fingerprint1'],
          failed_back_image_fingerprints: ['fingerprint2'],
          failed_selfie_image_fingerprints: nil,
        )
      end
    end
  end

  describe '#passport_requested?' do
    context 'when passport_status is allowed' do
      it 'returns false' do
        record = build(:document_capture_session)

        expect(record.passport_requested?).to eq(false)
      end
    end

    context 'when passport_status is requested' do
      it 'returns false' do
        record = build(:document_capture_session, passport_status: 'requested')

        expect(record.passport_requested?).to eq(true)
      end
    end
  end

  describe '#request_passport!' do
    it 'sets the correct attributes for a requested passport' do
      record = build(:document_capture_session)

      record.request_passport!

      expect(record).to have_attributes(
        passport_status: 'requested',
        doc_auth_vendor: nil,
        socure_docv_capture_app_url: nil,
        socure_docv_transaction_token: nil,
      )
    end
  end

  describe '#request_state_id!' do
    context 'passport was not requested before' do
      it 'sets the correct attributes for a not requested passport' do
        record = build(:document_capture_session)

        record.request_state_id!

        expect(record).to have_attributes(
          passport_status: 'not_requested',
          doc_auth_vendor: nil,
        )
      end
    end

    context 'passport was requested before' do
      it 'sets the socure attributes to nil' do
        record = build(
          :document_capture_session,
          passport_status: 'requested',
          socure_docv_capture_app_url: 'some-url',
          socure_docv_transaction_token: '12345',
        )

        record.request_state_id!

        expect(record).to have_attributes(
          passport_status: 'not_requested',
          doc_auth_vendor: nil,
          socure_docv_capture_app_url: nil,
          socure_docv_transaction_token: nil,
        )
      end
    end
  end
end
