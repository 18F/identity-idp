require 'rails_helper'

describe Idv::DocumentCaptureForm do
  let(:liveness_enabled) { false }
  let(:subject) { Idv::DocumentCaptureForm.new(liveness_checking_enabled: liveness_enabled) }
  let(:front_image_data) { 'abc' }
  let(:front_image_data_url) { 'data:image/jpeg;base64,abc' }
  let(:back_image_data) { 'def' }
  let(:back_image_data_url) { 'data:image/jpeg;base64,def' }
  let(:selfie_image_data) { 'ghi' }
  let(:selfie_image_data_url) { 'data:image/jpeg;base64,ghi' }

  describe '#submit' do
    context 'when liveness checking is not enabled' do
      context 'when the form has front and back images' do
        it 'returns a successful form response' do
          result = subject.submit(
            front_image: front_image_data,
            back_image: back_image_data,
          )

          expect(result).to be_kind_of(FormResponse)
          expect(result.success?).to eq(true)
          expect(result.errors).to be_empty
        end
      end

      context 'when the form has a front and back data_urls' do
        it 'returns a successful form response' do
          result = subject.submit(
            front_image: front_image_data_url,
            back_image: back_image_data_url,
          )

          expect(result).to be_kind_of(FormResponse)
          expect(result.success?).to eq(true)
          expect(result.errors).to be_empty
        end
      end
    end

    context 'when liveness checking is enabled' do
      let(:liveness_enabled) { true }

      context 'when the form has front, back, and selfie images' do
        it 'returns a successful form response' do
          result = subject.submit(
            front_image: front_image_data,
            back_image: back_image_data,
            selfie_image: selfie_image_data,
          )

          expect(result).to be_kind_of(FormResponse)
          expect(result.success?).to eq(true)
          expect(result.errors).to be_empty
        end
      end

      context 'when the form only has front and back images' do
        it 'returns a successful form response' do
          result = subject.submit(
            front_image: front_image_data,
            back_image: back_image_data,
          )

          expect(result).to be_kind_of(FormResponse)
          expect(result.success?).to eq(false)
          expect(subject.errors).to include(:selfie_image)
        end
      end
    end

    context 'when the form has invalid attributes' do
      it 'raises an error' do
        expect do
          subject.submit(
            front_image: front_image_data,
            back_image: back_image_data_url,
            foo: 1,
          )
        end.to raise_error(ArgumentError, 'foo is an invalid image attribute')
      end
    end
  end

  describe 'presence validations' do
    context 'when liveness checking is not enabled' do
      it 'is invalid when image and data_url attributes are not present' do
        result = subject.submit({})

        expect(subject).to_not be_valid
        expect(subject.errors).to include(:front_image)
        expect(subject.errors).to include(:back_image)
        expect(subject.errors).not_to include(:selfie_image)
        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
      end
    end

    context 'when liveness checking is enabled' do
      let(:liveness_enabled) { true }

      it 'is invalid when image and data_url attributes are not present' do
        result = subject.submit({})

        expect(subject).to_not be_valid
        expect(subject.errors).to include(:front_image)
        expect(subject.errors).to include(:back_image)
        expect(subject.errors).to include(:selfie_image)
        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
      end
    end
  end
end
