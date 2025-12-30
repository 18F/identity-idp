# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Idv::SocureErrorsConcern do
  let(:test_class) do
    Class.new do
      include Idv::SocureErrorsConcern

      def document_capture_session
        @document_capture_session ||= Struct.new(:user).new(User.new)
      end
    end
  end

  let(:instance) { test_class.new }

  describe '#error_code_for' do
    subject(:error_code) { instance.send(:error_code_for, result) }

    context 'when result has unaccepted_id_type error' do
      let(:result) { FormResponse.new(success: false, errors: { unaccepted_id_type: true }) }

      it 'returns :unaccepted_id_type' do
        expect(error_code).to eq(:unaccepted_id_type)
      end
    end

    context 'when result has selfie_fail error' do
      let(:result) { FormResponse.new(success: false, errors: { selfie_fail: true }) }

      it 'returns :selfie_fail' do
        expect(error_code).to eq(:selfie_fail)
      end
    end

    context 'when result has unexpected_id_type error' do
      let(:result) { FormResponse.new(success: false, errors: { unexpected_id_type: true }) }

      it 'returns :unexpected_id_type' do
        expect(error_code).to eq(:unexpected_id_type)
      end
    end

    context 'when result has socure error with reason codes' do
      let(:result) do
        FormResponse.new(
          success: false,
          errors: { socure: { reason_codes: ['R810', 'R820'] } },
        )
      end

      it 'returns the first reason code' do
        expect(error_code).to eq('R810')
      end
    end

    context 'when result has network error' do
      let(:result) { FormResponse.new(success: false, errors: { network: true }) }

      it 'returns :network' do
        expect(error_code).to eq(:network)
      end
    end

    context 'when result has pii_validation error' do
      let(:result) { FormResponse.new(success: false, errors: { pii_validation: true }) }

      it 'returns :pii_validation' do
        expect(error_code).to eq(:pii_validation)
      end
    end

    context 'when result has verification error (AAMVA failure)' do
      let(:result) do
        FormResponse.new(
          success: false,
          errors: { verification: 'Document could not be verified.' },
        )
      end

      it 'returns :state_id_verification' do
        expect(error_code).to eq(:state_id_verification)
      end
    end

    context 'when result has no recognized error type' do
      let(:result) { FormResponse.new(success: false, errors: {}) }

      it 'returns :network as default' do
        expect(error_code).to eq(:network)
      end
    end
  end
end
