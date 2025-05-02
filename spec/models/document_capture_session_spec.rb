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
        state_id_type: 'drivers_license',
        zipcode: '12345',
        issuing_country_code: 'USA',
      ),
      extra: {
        doc_auth_result: 'Passed',
      },
    )
  end

  let(:failed_doc_auth_response) do
    DocAuth::Response.new(
      success: false,
    )
  end

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

    context 'passport_status is allowed' do
      it 'does not throws error' do
        expect { create(:document_capture_session, passport_status: 'allowed') }
          .not_to raise_error(ActiveRecord::RecordInvalid)
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
    it 'generates a result ID stores the result encrypted in redis' do
      record = DocumentCaptureSession.new

      record.store_result_from_response(doc_auth_response)

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
        record.store_result_from_response(doc_auth_response)
        expect(record.ocr_confirmation_pending).to eq(true)
      end
    end
  end

  describe '#load_result' do
    it 'loads the previously stored result' do
      record = DocumentCaptureSession.new
      record.store_result_from_response(doc_auth_response)
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

  describe('#store_failed_auth_data') do
    it 'stores image finger print' do
      record = DocumentCaptureSession.new(result_id: SecureRandom.uuid)
      record.store_failed_auth_data(
        front_image_fingerprint: 'fingerprint1',
        back_image_fingerprint: nil,
        passport_image_fingerprint: nil,
        selfie_image_fingerprint: nil,
        doc_auth_success: false,
        selfie_status: :not_processed,
      )
      result_id = record.result_id
      key = EncryptedRedisStructStorage.key(result_id, type: DocumentCaptureSessionResult)
      data = REDIS_POOL.with { |client| client.get(key) }
      expect(data).to be_a(String)
      result = record.load_result
      expect(result.failed_front_image?('fingerprint1')).to eq(true)
      expect(result.failed_front_image?(nil)).to eq(false)
      expect(result.failed_back_image?(nil)).to eq(false)
      expect(result.doc_auth_success).to eq(false)
      expect(result.selfie_status).to eq(:not_processed)
    end

    it 'saves failed image fingerprints' do
      record = DocumentCaptureSession.new(result_id: SecureRandom.uuid)

      record.store_failed_auth_data(
        front_image_fingerprint: 'fingerprint1',
        back_image_fingerprint: nil,
        passport_image_fingerprint: nil,
        selfie_image_fingerprint: nil,
        doc_auth_success: false,
        selfie_status: :not_processed,
      )
      old_result = record.load_result

      record.store_failed_auth_data(
        front_image_fingerprint: 'fingerprint2',
        back_image_fingerprint: 'fingerprint3',
        passport_image_fingerprint: nil,
        selfie_image_fingerprint: nil,
        doc_auth_success: false,
        selfie_status: :not_processed,
      )
      new_result = record.load_result

      expect(old_result.failed_front_image?('fingerprint1')).to eq(true)
      expect(old_result.failed_front_image?('fingerprint2')).to eq(false)
      expect(old_result.failed_back_image?('fingerprint3')).to eq(false)
      expect(old_result.failed_selfie_image_fingerprints).to be_nil
      expect(old_result.doc_auth_success).to eq(false)
      expect(old_result.selfie_status).to eq(:not_processed)

      expect(new_result.failed_front_image?('fingerprint1')).to eq(true)
      expect(new_result.failed_front_image?('fingerprint2')).to eq(true)
      expect(new_result.failed_back_image?('fingerprint3')).to eq(true)
      expect(new_result.failed_selfie_image_fingerprints).to be_nil
      expect(new_result.doc_auth_success).to eq(false)
      expect(new_result.selfie_status).to eq(:not_processed)

      old_result = new_result

      record.store_failed_auth_data(
        front_image_fingerprint: 'fingerprint2',
        back_image_fingerprint: 'fingerprint3',
        passport_image_fingerprint: nil,
        selfie_image_fingerprint: 'fingerprint4',
        doc_auth_success: false,
        selfie_status: :fail,
      )
      new_result = record.load_result

      expect(old_result.failed_front_image?('fingerprint1')).to eq(true)
      expect(old_result.failed_front_image?('fingerprint2')).to eq(true)
      expect(old_result.failed_back_image?('fingerprint3')).to eq(true)
      expect(old_result.failed_selfie_image_fingerprints).to be_nil
      expect(old_result.doc_auth_success).to eq(false)
      expect(old_result.selfie_status).to eq(:not_processed)

      expect(new_result.failed_front_image_fingerprints.length).to eq(2)
      expect(new_result.failed_back_image_fingerprints.length).to eq(1)
      expect(new_result.failed_selfie_image?('fingerprint4')).to eq(true)
      expect(new_result.doc_auth_success).to eq(false)
      expect(new_result.selfie_status).to eq(:fail)
    end

    context 'when selfie is successful' do
      it 'does not add selfie to failed image fingerprints' do
        record = DocumentCaptureSession.new(result_id: SecureRandom.uuid)

        record.store_failed_auth_data(
          front_image_fingerprint: 'fingerprint1',
          back_image_fingerprint: 'fingerprint2',
          passport_image_fingerprint: nil,
          selfie_image_fingerprint: 'fingerprint3',
          doc_auth_success: false,
          selfie_status: :pass,
        )
        result = record.load_result

        expect(result.failed_front_image?('fingerprint1')).to eq(true)
        expect(result.failed_back_image?('fingerprint2')).to eq(true)
        expect(result.failed_selfie_image_fingerprints).to be_nil
      end
    end
  end

  describe('#passport_allowed') do
    it 'returns nil by default' do
      record = build(:document_capture_session)
      expect(record.passport_allowed?).to eq(false)
    end

    context 'when passport_status is allowed' do
      it 'returns true' do
        record = build(:document_capture_session, passport_status: 'allowed')
        expect(record.passport_allowed?).to eq(true)
      end
    end

    context 'when passport_status is requested' do
      it 'returns true' do
        record = build(:document_capture_session, passport_status: 'requested')
        expect(record.passport_allowed?).to eq(true)
      end
    end
  end

  describe('#passport_requested') do
    it 'returns nil by default' do
      record = build(:document_capture_session)
      expect(record.passport_allowed?).to eq(false)
    end

    context 'when passport_status is allowed' do
      it 'returns false' do
        record = build(:document_capture_session, passport_status: 'allowed')
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
end
