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

  # def selfie_requirement_met?
  #   !decorated_sp_session.selfie_required? || stored_result.selfie_check_performed
  # end

  describe '#selfie_requirement_met?' do
    controller(idv_document_capture_controller_class) do
    end

    context 'selfie checks enabled' do
      before do
        decorated_sp_session = double
        allow(decorated_sp_session).to receive(:selfie_required?).and_return(selfie_required)
        allow(controller).to receive(:decorated_sp_session).and_return(decorated_sp_session)
        stored_result = double
        allow(stored_result).to receive(:selfie_check_performed).and_return(selfie_check_performed)
        allow(controller).to receive(:stored_result).and_return(stored_result)
      end

      context 'SP requires biometric_comparison' do
        let(:selfie_required) { true }

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

      context 'SP does not require biometric_comparison' do
        let(:selfie_required) { false }

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
