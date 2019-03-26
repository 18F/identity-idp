require 'rails_helper'

describe Idv::ImageUploadForm do
  let(:subject) { Idv::ImageUploadForm.new }
  let(:image_data) { 'abc' }

  describe '#submit' do
    context 'when the form is valid' do
      it 'returns a successful form response' do
        result = subject.submit(image: image_data)

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
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
    it 'is invalid when required attribute is not present' do
      subject.submit(image: nil)

      expect(subject).to_not be_valid
    end
  end
end
