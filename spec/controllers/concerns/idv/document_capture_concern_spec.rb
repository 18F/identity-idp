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
      before do
        stored_result = instance_double(DocumentCaptureSessionResult)
        allow(stored_result).to receive(:selfie_check_performed?).and_return(selfie_check_performed)
        allow(controller).to receive(:stored_result).and_return(stored_result)

        resolution_result = Vot::Parser.new(vector_of_trust: vot).parse
        allow(controller).to receive(:resolved_authn_context_result).and_return(resolution_result)
      end

      context 'SP requires facial_match' do
        let(:vot) { 'Pb' }

        context 'selfie check performed' do
          let(:selfie_check_performed) { true }

          it 'returns true' do
            expect(controller.selfie_requirement_met?).to eq(true)
          end
        end

        context 'selfie check not performed' do
          let(:selfie_check_performed) { false }

          it 'returns false' do
            expect(controller.selfie_requirement_met?).to eq(false)
          end
        end
      end

      context 'SP does not require facial_match' do
        let(:vot) { 'P1' }

        context 'selfie check performed' do
          let(:selfie_check_performed) { true }

          it 'returns true' do
            expect(controller.selfie_requirement_met?).to eq(true)
          end
        end

        context 'selfie check not performed' do
          let(:selfie_check_performed) { false }
          it 'returns true' do
            expect(controller.selfie_requirement_met?).to eq(true)
          end
        end
      end
    end
  end
end
