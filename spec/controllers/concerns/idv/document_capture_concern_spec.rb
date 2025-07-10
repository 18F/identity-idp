require 'rails_helper'

RSpec.describe Idv::DocumentCaptureConcern, :controller do
  idv_document_capture_controller_class = Class.new(ApplicationController) do
    def self.name
      'AnonymousController'
    end

    include Idv::DocumentCaptureConcern

    def show
      render plain: 'Hello'
    end
  end

  describe '#handle_stored_result' do
    controller(idv_document_capture_controller_class) do
    end

    let(:user) { build(:user) }
    let(:document_capture_session) { instance_double(DocumentCaptureSession) }
    let(:mrz_status) { nil }
    let(:selfie_status) { :not_processed }
    let(:success) { true }

    before do
      id = SecureRandom.hex
      result = DocumentCaptureSessionResult.new(
        id:,
        success:,
        doc_auth_success: true,
        selfie_status:,
        mrz_status:,
        pii: { first_name: 'Test', last_name: 'User', state: 'MD' },
        attention_with_barcode: false,
      )
      EncryptedRedisStructStorage.store(result)
      stored_result = EncryptedRedisStructStorage.load(id, type: DocumentCaptureSessionResult)
      allow(controller).to receive(:stored_result).and_return(stored_result)
      allow(controller).to receive(:document_capture_session).and_return(document_capture_session)
      allow(controller).to receive(:current_user).and_return(user)
      allow(controller).to receive(:flash).and_return({})
      allow(controller).to receive(:track_document_issuing_state)

      resolution_result = Vot::Parser.new(vector_of_trust: 'P1').parse
      allow(controller).to receive(:resolved_authn_context_result).and_return(resolution_result)
    end

    context 'when document is a passport with failed MRZ check' do
      let(:mrz_status) { :failed }

      before do
        allow(controller).to receive(:id_type).and_return('passport')
      end

      it 'returns failure response' do
        response = controller.handle_stored_result(user: user)
        expect(response.success?).to eq(false)
      end
    end

    context 'when document is a passport with passed MRZ check' do
      let(:mrz_status) { :pass }

      before do
        allow(controller).to receive(:id_type).and_return('passport')
        # Update the stored result to include valid passport PII
        id = SecureRandom.hex
        result = DocumentCaptureSessionResult.new(
          id:,
          success:,
          doc_auth_success: true,
          selfie_status:,
          mrz_status:,
          pii: {
            first_name: 'Test',
            last_name: 'User',
            state: 'MD',
            mrz: "P<USADOE<<JOHN<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n" \
                 "123456789<USA7006100M2501017<<<<<<<<<<<<<<06\n",
            document_number: '123456789',
            passport_expiration: '2030-01-01',
            issuing_country_code: 'USA',
            nationality_code: 'USA',
            dob: '1970-06-10',
          },
          attention_with_barcode: false,
        )
        EncryptedRedisStructStorage.store(result)
        stored_result = EncryptedRedisStructStorage.load(id, type: DocumentCaptureSessionResult)
        allow(controller).to receive(:stored_result).and_return(stored_result)
      end

      it 'returns success response' do
        response = controller.handle_stored_result(user: user, store_in_session: false)
        expect(response.success?).to eq(true)
      end
    end

    context 'when document is a state ID' do
      before do
        allow(controller).to receive(:id_type).and_return('state_id')
      end

      it 'returns success response regardless of MRZ status' do
        response = controller.handle_stored_result(user: user, store_in_session: false)
        expect(response.success?).to eq(true)
      end
    end
  end

  describe '#selfie_requirement_met?' do
    controller(idv_document_capture_controller_class) do
    end

    context 'selfie checks enabled' do
      let(:selfie_status) { :not_processed }
      before do
        id = SecureRandom.hex
        result = DocumentCaptureSessionResult.new(
          id:,
          success: true,
          doc_auth_success: true,
          selfie_status:,
          pii: {},
          attention_with_barcode: false,
        )
        EncryptedRedisStructStorage.store(result)
        stored_result = EncryptedRedisStructStorage.load(id, type: DocumentCaptureSessionResult)
        allow(controller).to receive(:stored_result).and_return(stored_result)

        resolution_result = Vot::Parser.new(vector_of_trust: vot).parse
        allow(controller).to receive(:resolved_authn_context_result).and_return(resolution_result)
      end

      context 'SP requires facial_match' do
        let(:vot) { 'Pb' }

        context 'selfie check not processed' do
          it 'returns false' do
            expect(controller.selfie_requirement_met?).to eq(false)
          end
        end

        context ' selfie check proccessed' do
          context 'selfie check pass' do
            let(:selfie_status) { :success }

            it 'returns true' do
              expect(controller.selfie_requirement_met?).to eq(true)
            end
          end

          context 'selfie check fail' do
            let(:selfie_status) { :fail }

            it 'returns true' do
              expect(controller.selfie_requirement_met?).to eq(true)
            end
          end
        end
      end

      context 'SP does not require facial_match' do
        let(:vot) { 'P1' }

        context 'selfie check not processed' do
          it 'returns true' do
            expect(controller.selfie_requirement_met?).to eq(true)
          end
        end

        context 'selfie check pass' do
          let(:selfie_status) { :success }

          it 'returns true' do
            expect(controller.selfie_requirement_met?).to eq(true)
          end
        end

        context 'selfie check fail' do
          let(:selfie_status) { :fail }

          it 'returns true' do
            expect(controller.selfie_requirement_met?).to eq(true)
          end
        end
      end
    end
  end

  describe '#mrz_requirement_met?' do
    controller(idv_document_capture_controller_class) do
    end

    let(:mrz_status) { nil }
    let(:document_capture_session) { instance_double(DocumentCaptureSession) }

    before do
      id = SecureRandom.hex
      result = DocumentCaptureSessionResult.new(
        id:,
        success: true,
        doc_auth_success: true,
        selfie_status: :not_processed,
        mrz_status:,
        pii: {},
        attention_with_barcode: false,
      )
      EncryptedRedisStructStorage.store(result)
      stored_result = EncryptedRedisStructStorage.load(id, type: DocumentCaptureSessionResult)
      allow(controller).to receive(:stored_result).and_return(stored_result)
      allow(controller).to receive(:document_capture_session).and_return(document_capture_session)
    end

    context 'when document is a state ID' do
      before do
        allow(controller).to receive(:id_type).and_return('state_id')
      end

      it 'returns true regardless of mrz_status' do
        expect(controller.mrz_requirement_met?).to eq(true)
      end
    end

    context 'when document is a passport' do
      before do
        allow(controller).to receive(:id_type).and_return('passport')
      end

      context 'when mrz_status is pass' do
        let(:mrz_status) { :pass }

        before do
          # Update the stored result to include valid passport PII
          id = SecureRandom.hex
          result = DocumentCaptureSessionResult.new(
            id:,
            success: true,
            doc_auth_success: true,
            selfie_status: :not_processed,
            mrz_status:,
            pii: {
              mrz: "P<USADOE<<JOHN<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n" \
                 "123456789<USA7006100M2501017<<<<<<<<<<<<<<06\n",
              document_number: '123456789',
              passport_expiration: '2030-01-01',
              issuing_country_code: 'USA',
              nationality_code: 'USA',
              dob: '1970-06-10',
            },
            attention_with_barcode: false,
          )
          EncryptedRedisStructStorage.store(result)
          stored_result = EncryptedRedisStructStorage.load(id, type: DocumentCaptureSessionResult)
          allow(controller).to receive(:stored_result).and_return(stored_result)
        end

        it 'returns true' do
          expect(controller.mrz_requirement_met?).to eq(true)
        end
      end

      context 'when mrz_status is failed' do
        let(:mrz_status) { :failed }

        it 'returns false' do
          expect(controller.mrz_requirement_met?).to eq(false)
        end
      end

      context 'when mrz_status is not_processed' do
        let(:mrz_status) { :not_processed }

        it 'returns false' do
          expect(controller.mrz_requirement_met?).to eq(false)
        end
      end

      context 'when mrz_status is nil' do
        let(:mrz_status) { nil }

        it 'returns false' do
          expect(controller.mrz_requirement_met?).to eq(false)
        end
      end

      context 'when mrz_status is pass but additional checks fail' do
        let(:mrz_status) { :pass }

        context 'when passport is expired' do
          before do
            id = SecureRandom.hex
            result = DocumentCaptureSessionResult.new(
              id:,
              success: true,
              doc_auth_success: true,
              selfie_status: :not_processed,
              mrz_status:,
              pii: {
                passport_expiration: '2020-01-01', # Expired
                issuing_country_code: 'USA',
                dob: '1970-06-10',
              },
              attention_with_barcode: false,
            )
            EncryptedRedisStructStorage.store(result)
            stored_result = EncryptedRedisStructStorage.load(id, type: DocumentCaptureSessionResult)
            allow(controller).to receive(:stored_result).and_return(stored_result)
          end

          it 'returns false' do
            expect(controller.mrz_requirement_met?).to eq(false)
          end
        end

        context 'when issuing country is not supported' do
          before do
            id = SecureRandom.hex
            result = DocumentCaptureSessionResult.new(
              id:,
              success: true,
              doc_auth_success: true,
              selfie_status: :not_processed,
              mrz_status:,
              pii: {
                passport_expiration: '2030-01-01',
                issuing_country_code: 'CAN', # Not supported
                dob: '1970-06-10',
              },
              attention_with_barcode: false,
            )
            EncryptedRedisStructStorage.store(result)
            stored_result = EncryptedRedisStructStorage.load(id, type: DocumentCaptureSessionResult)
            allow(controller).to receive(:stored_result).and_return(stored_result)
          end

          it 'returns false' do
            expect(controller.mrz_requirement_met?).to eq(false)
          end
        end

        context 'when all validation checks pass' do
          before do
            id = SecureRandom.hex
            result = DocumentCaptureSessionResult.new(
              id:,
              success: true,
              doc_auth_success: true,
              selfie_status: :not_processed,
              mrz_status:,
              pii: {
                passport_expiration: '2030-01-01',
                issuing_country_code: 'USA',
                dob: '1970-06-10',
              },
              attention_with_barcode: false,
            )
            EncryptedRedisStructStorage.store(result)
            stored_result = EncryptedRedisStructStorage.load(id, type: DocumentCaptureSessionResult)
            allow(controller).to receive(:stored_result).and_return(stored_result)
          end

          it 'returns true' do
            expect(controller.mrz_requirement_met?).to eq(true)
          end
        end
      end
    end
  end
end
