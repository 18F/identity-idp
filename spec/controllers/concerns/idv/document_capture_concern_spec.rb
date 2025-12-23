require 'rails_helper'

RSpec.describe Idv::DocumentCaptureConcern, :controller do
  let(:acr_values) { Saml::Idp::Constants::IAL_VERIFIED_ACR }

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
    let(:passport_requested) { false }
    let(:doc_auth_success) { true }
    let(:attention_with_barcode) { false }
    let(:pii_data) do
      {
        first_name: 'Test',
        last_name: 'User',
        state: 'MD',
      }
    end
    let(:passport_pii_data) do
      pii_data.merge(
        mrz: "P<USADOE<<JOHN<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n" \
             "123456789<USA7006100M2501017<<<<<<<<<<<<<<06\n",
        document_number: '123456789',
        passport_expiration: '2030-01-01',
        issuing_country_code: 'USA',
        nationality_code: 'USA',
        dob: '1970-06-10',
        document_type_received: 'passport',
      )
    end

    before do
      id = SecureRandom.hex
      result = DocumentCaptureSessionResult.new(
        id:,
        success:,
        doc_auth_success:,
        selfie_status:,
        mrz_status:,
        pii: pii_data,
        attention_with_barcode:,
      )
      EncryptedRedisStructStorage.store(result)
      stored_result = EncryptedRedisStructStorage.load(id, type: DocumentCaptureSessionResult)
      allow(controller).to receive(:stored_result).and_return(stored_result)
      allow(controller).to receive(:document_capture_session).and_return(document_capture_session)
      allow(controller).to receive(:current_user).and_return(user)
      allow(controller).to receive(:flash).and_return({})
      allow(controller).to receive(:track_document_issuing_state)
      allow(document_capture_session).to receive(:passport_requested?)
        .and_return(passport_requested)
      allow(document_capture_session).to receive(:doc_auth_vendor)
        .and_return(Idp::Constants::Vendors::MOCK)

      resolution_result = Component::Parser.new(acr_values:).parse
      allow(controller).to receive(:resolved_authn_context_result).and_return(resolution_result)
    end

    context 'when document is a passport with failed MRZ check' do
      let(:mrz_status) { :failed }
      let(:passport_requested) { true }

      it 'returns failure response' do
        response = controller.handle_stored_result(user: user)
        expect(response.success?).to eq(false)
      end
    end

    context 'when document is a passport with passed MRZ check' do
      let(:mrz_status) { :pass }
      let(:passport_requested) { true }

      let(:pii_data) do
        {
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
          document_type_received: 'passport',
        }
      end

      it 'returns success response' do
        response = controller.handle_stored_result(user: user, store_in_session: false)
        expect(response.success?).to eq(true)
      end
    end

    context 'when document is a state ID' do
      let(:aamva_enabled) { true }
      let(:aamva_status) { :passed }

      before do
        allow(IdentityConfig.store).to receive(:idv_aamva_at_doc_auth_enabled)
          .and_return(aamva_enabled)

        id = SecureRandom.hex
        result = DocumentCaptureSessionResult.new(
          id:,
          success:,
          doc_auth_success:,
          selfie_status:,
          mrz_status:,
          aamva_status:,
          pii: pii_data,
          attention_with_barcode:,
        )
        EncryptedRedisStructStorage.store(result)
        stored_result = EncryptedRedisStructStorage.load(id, type: DocumentCaptureSessionResult)
        allow(controller).to receive(:stored_result).and_return(stored_result)
      end

      it 'returns success response regardless of MRZ status' do
        response = controller.handle_stored_result(user: user, store_in_session: false)
        expect(response.success?).to eq(true)
      end

      context 'with AAMVA enabled' do
        context 'when AAMVA check passes' do
          let(:aamva_status) { :passed }

          it 'returns success response' do
            response = controller.handle_stored_result(user: user, store_in_session: false)
            expect(response.success?).to eq(true)
          end
        end

        context 'when AAMVA check fails' do
          let(:aamva_status) { :failed }

          it 'returns failure response' do
            response = controller.handle_stored_result(user: user, store_in_session: false)
            expect(response.success?).to eq(false)
          end
        end

        context 'when AAMVA check not processed' do
          let(:aamva_status) { :not_processed }

          it 'returns failure response' do
            response = controller.handle_stored_result(user: user, store_in_session: false)
            expect(response.success?).to eq(false)
          end
        end
      end

      context 'with AAMVA disabled' do
        let(:aamva_enabled) { false }
        let(:aamva_status) { :failed }

        it 'returns success response even with failed AAMVA' do
          response = controller.handle_stored_result(user: user, store_in_session: false)
          expect(response.success?).to eq(true)
        end
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

        resolution_result = Component::Parser.new(acr_values:).parse
        allow(controller).to receive(:resolved_authn_context_result).and_return(resolution_result)
      end

      context 'SP requires facial_match' do
        let(:acr_values) { Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR }

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
        let(:acr_values) { Saml::Idp::Constants::IAL_VERIFIED_ACR }

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

  describe '#aamva_requirement_met?' do
    controller(idv_document_capture_controller_class) do
    end

    let(:aamva_status) { nil }
    let(:document_capture_session) { instance_double(DocumentCaptureSession) }
    let(:aamva_enabled) { true }
    let(:doc_auth_success) { true }
    let(:selfie_status) { :not_processed }
    let(:success) { true }
    let(:attention_with_barcode) { false }
    let(:pii_data) { {} }
    let(:state_id_pii_data) do
      {
        first_name: 'Test',
        last_name: 'User',
        state: 'MD',
        document_type_received: 'drivers_license',
      }
    end
    let(:passport_pii_data) do
      {
        first_name: 'Test',
        last_name: 'User',
        mrz: "P<USADOE<<JOHN<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n" \
             "123456789<USA7006100M2501017<<<<<<<<<<<<<<06\n",
        document_number: '123456789',
        passport_expiration: '2030-01-01',
        issuing_country_code: 'USA',
        nationality_code: 'USA',
        dob: '1970-06-10',
        document_type_received: 'passport',
      }
    end

    before do
      id = SecureRandom.hex
      result = DocumentCaptureSessionResult.new(
        id:,
        success:,
        doc_auth_success:,
        selfie_status:,
        aamva_status:,
        pii: pii_data,
        attention_with_barcode:,
      )
      EncryptedRedisStructStorage.store(result)
      stored_result = EncryptedRedisStructStorage.load(id, type: DocumentCaptureSessionResult)
      allow(controller).to receive(:stored_result).and_return(stored_result)
      allow(controller).to receive(:document_capture_session).and_return(document_capture_session)
      allow(IdentityConfig.store).to receive(:idv_aamva_at_doc_auth_enabled)
        .and_return(aamva_enabled)
    end

    context 'when document is a passport' do
      let(:pii_data) { passport_pii_data }

      it 'returns true regardless of AAMVA status' do
        expect(controller.aamva_requirement_met?).to eq(true)
      end

      context 'with failed AAMVA status' do
        let(:aamva_status) { :failed }

        it 'returns true' do
          expect(controller.aamva_requirement_met?).to eq(true)
        end
      end
    end

    context 'when AAMVA at doc auth is disabled' do
      let(:aamva_enabled) { false }
      let(:pii_data) { state_id_pii_data }

      it 'returns true regardless of AAMVA status' do
        expect(controller.aamva_requirement_met?).to eq(true)
      end

      context 'with failed AAMVA status' do
        let(:aamva_status) { :failed }

        it 'returns true' do
          expect(controller.aamva_requirement_met?).to eq(true)
        end
      end
    end

    context 'when document is a state ID and AAMVA is enabled' do
      let(:pii_data) { state_id_pii_data }

      context 'when aamva_status is :passed' do
        let(:aamva_status) { :passed }

        it 'returns true' do
          expect(controller.aamva_requirement_met?).to eq(true)
        end
      end

      context 'when aamva_status is :failed' do
        let(:aamva_status) { :failed }

        it 'returns false' do
          expect(controller.aamva_requirement_met?).to eq(false)
        end
      end

      context 'when aamva_status is :not_processed' do
        let(:aamva_status) { :not_processed }

        it 'returns false' do
          expect(controller.aamva_requirement_met?).to eq(false)
        end
      end

      context 'when aamva_status is nil' do
        let(:aamva_status) { nil }

        it 'returns false' do
          expect(controller.aamva_requirement_met?).to eq(false)
        end
      end
    end
  end

  describe '#mrz_requirement_met?' do
    controller(idv_document_capture_controller_class) do
    end

    let(:mrz_status) { nil }
    let(:document_capture_session) { instance_double(DocumentCaptureSession) }
    let(:passport_requested) { false }
    let(:doc_auth_success) { true }
    let(:selfie_status) { :not_processed }
    let(:success) { true }
    let(:attention_with_barcode) { false }
    let(:pii_data) { {} }
    let(:passport_pii_data) do
      {
        mrz: "P<USADOE<<JOHN<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n" \
             "123456789<USA7006100M2501017<<<<<<<<<<<<<<06\n",
        document_number: '123456789',
        passport_expiration: '2030-01-01',
        issuing_country_code: 'USA',
        nationality_code: 'USA',
        dob: '1970-06-10',
        document_type_received: 'passport',
      }
    end
    let(:partial_passport_pii_data) do
      {
        passport_expiration: '2030-01-01',
        issuing_country_code: 'USA',
        dob: '1970-06-10',
        document_type_received: 'passport',
      }
    end

    before do
      id = SecureRandom.hex
      result = DocumentCaptureSessionResult.new(
        id:,
        success:,
        doc_auth_success:,
        selfie_status:,
        mrz_status:,
        pii: pii_data,
        attention_with_barcode:,
      )
      EncryptedRedisStructStorage.store(result)
      stored_result = EncryptedRedisStructStorage.load(id, type: DocumentCaptureSessionResult)
      allow(controller).to receive(:stored_result).and_return(stored_result)
      allow(controller).to receive(:document_capture_session).and_return(document_capture_session)
      allow(document_capture_session).to receive(:passport_requested?)
        .and_return(passport_requested)
      allow(document_capture_session).to receive(:doc_auth_vendor)
        .and_return(Idp::Constants::Vendors::MOCK)
    end

    context 'when passport not requested' do
      let(:passport_requested) { false }

      it 'returns true' do
        expect(controller.mrz_requirement_met?).to eq(true)
      end
    end

    context 'when passport requested but state ID submitted' do
      let(:passport_requested) { true }

      before do
      end

      it 'returns false' do
        expect(controller.mrz_requirement_met?).to eq(false)
      end
    end

    context 'when document is a passport' do
      let(:passport_requested) { true }

      before do
      end

      context 'when mrz_status is pass' do
        let(:mrz_status) { :pass }

        let(:pii_data) { passport_pii_data }

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

        context 'when feature checks pass' do
          let(:pii_data) { partial_passport_pii_data }

          it 'returns true' do
            expect(controller.mrz_requirement_met?).to eq(true)
          end
        end
      end
    end
  end
end
