require 'rails_helper'

describe Idv::ImageUploadForm do
  let(:subject) { Idv::ImageUploadForm.new }
  let(:image_data) { 'abc' }
  let(:image_data_url) { 'data:image/jpeg;base64,abc' }

  describe '#submit' do
    context 'when the form has an image' do
      it 'returns a successful form response' do
        result = subject.submit(image: image_data)

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
        expect(result.extra).to eq(is_fallback_link: true)
      end
    end

    context 'when the form has an image_data_url' do
      it 'returns a successful form response' do
        result = subject.submit(image_data_url: image_data_url)

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
        expect(result.extra).to eq(is_fallback_link: false)
      end
    end

    context 'when the form has invalid attributes' do
      it 'raises an error' do
        expect { subject.submit(image: image_data, foo: 1) }.
          to raise_error(ArgumentError, 'foo is an invalid image attribute')
      end
    end
  end

  describe 'presence validations' do
    it 'is invalid when image and image_data_url attribute is not present' do
      result = subject.submit({})

      expect(subject).to_not be_valid
      expect(subject.errors).to include(:image)
      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
    end
  end
end
