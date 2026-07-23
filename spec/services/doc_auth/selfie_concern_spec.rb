require 'rails_helper'

RSpec.describe DocAuth::SelfieConcern do
  let(:face_error_message) { '' }
  let(:portrait_info) do
    {
      FaceErrorMessage: face_error_message,
    }
  end

  subject do
    Class.new do
      include DocAuth::SelfieConcern
      attr_reader :portrait_match_results
      def initialize(portrait_match_results)
        @portrait_match_results = portrait_match_results
      end
    end.new(portrait_info)
  end

  describe '#selfie_live?' do
    context 'no error message' do
      it 'returns true' do
        expect(subject.selfie_live?).to eq(true)
      end
    end

    context 'an error message other than liveness' do
      let(:face_error_message) { 'Another error message' }
      it 'returns true' do
        expect(subject.selfie_live?).to eq(true)
      end
    end

    context 'a non-live error message' do
      let(:face_error_message) { 'Liveness: NotLive' }
      it 'returns false' do
        expect(subject.selfie_live?).to eq(false)
      end
    end
  end

  describe '#selfie_check_passed?' do
    subject do
      selfie_status_value = selfie_status
      Class.new do
        include DocAuth::SelfieConcern
        define_method(:selfie_status) { selfie_status_value }
      end.new
    end

    context 'when the selfie check succeeded' do
      let(:selfie_status) { :success }
      it 'returns true' do
        expect(subject.selfie_check_passed?).to eq(true)
      end
    end

    context 'when the selfie check failed' do
      let(:selfie_status) { :fail }
      it 'returns false' do
        expect(subject.selfie_check_passed?).to eq(false)
      end
    end

    context 'when the selfie check was not processed' do
      let(:selfie_status) { :not_processed }
      it 'returns false' do
        expect(subject.selfie_check_passed?).to eq(false)
      end
    end
  end

  describe '#selfie_quality_good?' do
    context 'no error message' do
      it 'returns true' do
        expect(subject.selfie_quality_good?).to eq(true)
      end
    end

    context 'an error message other than quality' do
      let(:face_error_message) { 'Another error message' }
      it 'returns true' do
        expect(subject.selfie_live?).to eq(true)
      end
    end

    context 'a poor quality error message' do
      let(:face_error_message) { 'Liveness: PoorQuality' }
      it 'returns false' do
        expect(subject.selfie_quality_good?).to eq(false)
      end
    end
  end
end
