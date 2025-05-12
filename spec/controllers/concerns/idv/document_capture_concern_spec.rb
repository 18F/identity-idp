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
end
