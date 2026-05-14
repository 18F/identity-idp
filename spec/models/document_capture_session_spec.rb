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

  context 'validates document type requested' do
    context 'document_type_requested is invalid' do
      it 'throws error' do
        expect do
          create(:document_capture_session, document_type_requested: 'invalid')
        end.to raise_error(ArgumentError)
      end
    end

    context 'document_type_requested is valid' do
      it 'does not throw error' do
        expect { create(:document_capture_session, document_type_requested: Idp::Constants::DocumentTypes::PASSPORT) }
          .not_to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'passport is requested' do
      it 'does not throw error' do
        expect { create(:document_capture_session, document_type_requested: Idp::Constants::DocumentTypes::PASSPORT) }
          .not_to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'document_type_requested is nil' do
      it 'does not throws error' do
        expect { create(:document_capture_session, document_type_requested: nil) }
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

  context 'proofing agent' do
    let(:success) { true }
    let(:reason) { nil }
    let(:resolution) { { success: true } }
    let(:mrz) { nil }
    let(:aamva_success) { true }
    let(:aamva_vendor) { :document_check_vendor }
    let(:aamva_attrs) { %w[all of them] }
    let(:aamva) do
      {
        success: aamva_success,
        vendor_name: aamva_vendor,
        extra: {
          verified_attributes: aamva_attrs,
        }.compact,
      }
    end
    let(:agent_proofing_result) do
      {
        pii: { first_name: 'Testy', last_name: 'Testerson' },
        proofing_location_id: '123',
        proofing_agent_id: '456',
        correlation_id: '789',
        service_provider_issuer: 'test_issuer',
        success:,
        reason:,
        resolution:,
        mrz:,
        aamva:,
      }
    end

    describe '#load_agent_proofed_user' do
      it 'loads the previously stored result' do
        record = DocumentCaptureSession.new
        record.store_agent_proofed_user(agent_proofing_result)
        result = record.load_agent_proofed_user

        expect(result.success).to eq(agent_proofing_result[:success])
        expect(result.pii).to eq(agent_proofing_result[:pii])
      end

      it 'returns nil if the previously stored result does not exist' do
        record = DocumentCaptureSession.new
        result = record.load_agent_proofed_user

        expect(result).to eq(nil)
      end

      xit 'returns nil if the previously stored result is expired' do
        record = DocumentCaptureSession.new
        record.store_agent_proofed_user(agent_proofing_result)
        past_exp = IdentityConfig.store.agent_proofed_user_time_validity_hours.hours.in_seconds
        travel_to((2 * past_exp).seconds.from_now) do
          result = record.load_agent_proofed_user

          expect(result).to eq(nil)
        end
      end
    end

    describe '#store_agent_proofed_user' do
      let(:document_capture_session) { DocumentCaptureSession.new(result_id: SecureRandom.uuid) }

      it 'generates a result ID stores the result encrypted in redis' do
        record = document_capture_session
        record.store_agent_proofed_user(agent_proofing_result)

        result_id = record.result_id
        key = EncryptedRedisStructStorage.key(result_id, type: Idv::ProofingAgent::AgentProofedUser)
        data = REDIS_POOL.with { |client| client.get(key) }
        expect(data).to be_a(String)
        expect(data).to_not be_blank
        expect(data).to_not include('Testy')
        expect(data).to_not include('Testerson')
      end

      context 'when all fields are passed in' do
        let(:current_time) { Time.zone.now }

        before do
          freeze_time
          travel_to(current_time) do
            document_capture_session.store_agent_proofed_user(agent_proofing_result)
          end
        end

        it 'stores the results' do
          expect(document_capture_session.load_agent_proofed_user).to have_attributes(
            success: true,
            reason: nil,
            pii: agent_proofing_result[:pii],
            proofing_location_id: '123',
            proofing_agent_id: '456',
            correlation_id: '789',
            issuer: 'test_issuer',
            captured_at: current_time,
            resolution: { success: true },
            mrz_status: :not_processed,
            aamva_status: :passed,
          )
        end
      end

      context 'when aamva response is passed in' do
        before do
          document_capture_session.store_agent_proofed_user(agent_proofing_result)
        end

        context 'when the aamva response is successful' do
          it 'stores aamva_status as :passed' do
            expect(document_capture_session.load_agent_proofed_user).to have_attributes(
              aamva_status: :passed,
              aamva_verified_attributes: aamva_attrs,
              source_check_vendor: aamva_vendor,
            )
          end
        end

        context 'when the aamva response is unsuccessful' do
          let(:aamva_success) { false }
          let(:aamva_attrs) { nil }

          it 'stores aamva_status as :failed' do
            expect(document_capture_session.load_agent_proofed_user).to have_attributes(
              aamva_status: :failed,
              source_check_vendor: aamva_vendor,
            )
          end
        end

        context 'when the aamva response is nil' do
          let(:aamva) { nil }

          it 'stores aamva_status as :not_processed' do
            expect(document_capture_session.load_agent_proofed_user).to have_attributes(
              aamva_status: :not_processed,
            )
          end
        end
      end

      context 'when both aamva and mrz response is passed in' do
        let(:aamva) { { success: true } }
        let(:mrz) { { success: true } }

        it 'raises an exception' do
          expect do
            document_capture_session.store_agent_proofed_user(agent_proofing_result)
          end.to raise_error(ArgumentError, 'received both aamva and mrz args')
        end
      end

      context 'when mrz response is passed in' do
        let(:aamva) { nil }
        before do
          document_capture_session.store_agent_proofed_user(agent_proofing_result)
        end

        context 'when the mrz response is successful' do
          let(:mrz) { { success: true, vendor_name: 'test_dos' } }

          it 'stores mrz_status as :passed' do
            expect(document_capture_session.load_agent_proofed_user).to have_attributes(
              mrz_status: :pass,
              source_check_vendor: :test_dos,
            )
          end
        end

        context 'when the mrz response is unsuccessful' do
          let(:mrz) { { success: false, vendor_name: 'test_dos' } }

          it 'stores mrz_status as :failed' do
            expect(document_capture_session.load_agent_proofed_user).to have_attributes(
              mrz_status: :failed,
              source_check_vendor: :test_dos,
            )
          end
        end
        context 'when the mrz response is nil' do
          let(:mrz_response) { nil }

          it 'stores mrz_status as :not_processed' do
            expect(document_capture_session.load_agent_proofed_user).to have_attributes(
              mrz_status: :not_processed,
            )
          end
        end
      end
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

  context 'when document_type_requested is nil' do
    it 'returns false' do
      record = build(:document_capture_session, document_type_requested: nil)

      expect(record.passport_requested?).to eq(false)
      expect(record.state_id_requested?).to eq(false)
    end
  end

  describe '#request_passport!' do
    it 'sets the correct attributes for a requested passport' do
      record = build(
        :document_capture_session,
        socure_docv_capture_app_url: 'hello',
        socure_docv_transaction_token: 'world',
      )

      record.request_passport!

      expect(record).to have_attributes(
        passport_status: nil,
        document_type_requested: Idp::Constants::DocumentTypes::PASSPORT,
        doc_auth_vendor: nil,
        socure_docv_capture_app_url: nil,
        socure_docv_transaction_token: nil,
      )

      expect(record.passport_requested?).to eq(true)
      expect(record.state_id_requested?).to eq(false)
    end

    context 'when state_id was requested before' do
      it 'clears the socure attributes' do
        record = build(
          :document_capture_session,
          document_type_requested: Idp::Constants::DocumentTypes::STATE_ID_CARD,
          doc_auth_vendor: nil,
          socure_docv_capture_app_url: 'some-url',
          socure_docv_transaction_token: '12345',
        )

        record.request_passport!

        expect(record).to have_attributes(
          passport_status: nil,
          document_type_requested: Idp::Constants::DocumentTypes::PASSPORT,
          doc_auth_vendor: nil,
          socure_docv_capture_app_url: nil,
          socure_docv_transaction_token: nil,
        )
      end
    end
  end

  describe '#request_state_id!' do
    context 'passport was not requested before' do
      it 'sets the correct attributes for a not requested passport' do
        record = build(
          :document_capture_session,
          socure_docv_capture_app_url: 'hello',
          socure_docv_transaction_token: 'world',
        )

        record.request_state_id!

        expect(record).to have_attributes(
          passport_status: nil,
          document_type_requested: Idp::Constants::DocumentTypes::STATE_ID_CARD,
          doc_auth_vendor: nil,
          socure_docv_capture_app_url: nil,
          socure_docv_transaction_token: nil,
        )

        expect(record.passport_requested?).to eq(false)
        expect(record.state_id_requested?).to eq(true)
      end
    end

    context 'passport was requested before' do
      it 'sets the socure attributes to nil' do
        record = build(
          :document_capture_session,
          document_type_requested: Idp::Constants::DocumentTypes::PASSPORT,
          doc_auth_vendor: 'a vendor',
          socure_docv_capture_app_url: 'some-url',
          socure_docv_transaction_token: '12345',
        )

        record.request_state_id!

        expect(record).to have_attributes(
          passport_status: nil,
          document_type_requested: Idp::Constants::DocumentTypes::STATE_ID_CARD,
          doc_auth_vendor: nil,
          socure_docv_capture_app_url: nil,
          socure_docv_transaction_token: nil,
        )

        expect(record.passport_requested?).to eq(false)
        expect(record.state_id_requested?).to eq(true)
      end
    end
  end
end
