require 'rails_helper'

RSpec.describe Idv::DocumentCaptureConcern, :controller do
  let(:user_session) do
    {}
  end
  let(:idv_session) do
    Idv::Session.new(
      user_session:,
      current_user: user,
      service_provider: nil,
    )
  end

  let(:user) { build(:user) }
  let(:document_capture_session) { instance_double(DocumentCaptureSession) }

  idv_document_capture_controller_class = Class.new(ApplicationController) do
    def self.name
      'AnonymousController'
    end

    include Idv::DocumentCaptureConcern

    def show
      render plain: 'Hello'
    end
  end

  before do
    idv_session.pii_from_doc = { id_doc_type: 'drivers_license' }
    allow(controller).to receive(:idv_session).and_return(idv_session)
    allow(document_capture_session).to receive(:doc_auth_vendor).and_return('mock')
  end
  describe '#handle_stored_result' do
    controller(idv_document_capture_controller_class) do
    end

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

    context 'when passports' do
      before do
        idv_session.pii_from_doc = { id_doc_type: 'passport' }
      end

      context 'when passports are enabled' do
        before do
          allow(document_capture_session).to receive(:passport_requested?).and_return(true)
          allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled).and_return(true)
        end

        context 'when document is a passport with failed MRZ check' do
          let(:mrz_status) { :failed }

          it 'returns failure response' do
            response = controller.handle_stored_result(user: user)
            expect(response.success?).to eq(false)
          end
        end

        context 'when document is a passport with passed MRZ check' do
          let(:mrz_status) { :pass }

          before do
            allow(controller).to receive(:id_type).and_return('passport')
          end

          it 'returns success response' do
            response = controller.handle_stored_result(user: user, store_in_session: false)
            expect(response.success?).to eq(true)
          end
        end
      end

      context 'when doc_auth_passports_enabled is false' do
        before do
          allow(document_capture_session).to receive(:passport_requested?).and_return(false)
          allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled).and_return(false)
        end

        context 'when document is a passport with failed MRZ check' do
          let(:mrz_status) { :failed }

          it 'returns failure response' do
            response = controller.handle_stored_result(user: user)
            expect(response.success?).to eq(false)
          end
        end

        context 'when document is a passport with passed MRZ check' do
          let(:mrz_status) { :pass }

          before do
            allow(controller).to receive(:id_type).and_return('passport')
          end

          it 'returns success response' do
            response = controller.handle_stored_result(user: user, store_in_session: false)
            expect(response.success?).to eq(false)
          end
        end
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
    end
  end
end
