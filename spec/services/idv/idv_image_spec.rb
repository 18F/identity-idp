require 'rails_helper'

RSpec.describe Idv::IdvImage do
  let(:back_image) { DocAuthImageFixtures.document_back_image_multipart }
  let(:type) { :back }
  let(:value) { back_image }
  subject(:image) { described_class.new(type:, value:) }

  describe '#initialize' do
    it 'sets the type' do
      expect(subject.type).to eq(:back)
    end

    it 'sets the image value' do
      expect(subject.value).to eq back_image
    end

    context 'when the value is a string' do
      let(:data) { 'abc' }
      let(:back_image) { "data:image/jpeg,#{Addressable::URI.encode(data)}" }

      it 'sets the image value as a readable Idv::DataUrlImage' do
        expect(subject.value).to be_a_kind_of(Idv::DataUrlImage)
      end

      context 'with bad data' do
        let(:back_image) { 'not_a_url' }
        it 'sets the image value as an Idv::DataUrlImage::InvalidUrlFormatError' do
          expect(subject.value).to be_a_kind_of(Idv::DataUrlImage::InvalidUrlFormatError)
        end
      end

      context 'when image is an empty string' do
        let(:back_image) { '' }

        it 'sets the image value as an Idv::DataUrlImage::InvalidUrlFormatError' do
          expect(subject.value).to be_a_kind_of(Idv::DataUrlImage::InvalidUrlFormatError)
        end
      end
    end
  end

  describe '#bytes' do
    context 'with a readable value' do
      it 'returns the readable value' do
        # uploaded files can only be read once, so using a fresh version of the image to test
        image = DocAuthImageFixtures.document_back_image_multipart
        expect(subject.bytes).to eq image.read
      end

      context 'when the value is a DataUrlImage object' do
        let(:data) { 'abc' }
        let(:back_image) { "data:image/jpeg,#{Addressable::URI.encode(data)}" }

        it 'returns the readable value' do
          expect(subject.bytes).to eq data
        end
      end
    end

    context 'with an unreadable value' do
      let(:back_image) { '' }
      it 'returns nil' do
        expect(subject.bytes).to be nil
      end
    end
  end

  describe '#fingerprint' do
    context 'with a readable value' do
      it 'returns the sha256 base64 digest' do
        # uploaded files can only be read once, so using a fresh version of the image to test
        image = DocAuthImageFixtures.document_back_image_multipart

        expect(subject.fingerprint).to eq Digest::SHA256.urlsafe_base64digest(image.read)
      end

      context 'when the value is a DataUrlImage object' do
        let(:data) { 'abc' }
        let(:back_image) { "data:image/jpeg,#{Addressable::URI.encode(data)}" }

        it 'returns the readable value' do
          expect(subject.fingerprint).to eq Digest::SHA256.urlsafe_base64digest(data)
        end
      end
    end

    context 'with an unreadable value' do
      let(:back_image) { '' }
      it 'returns nil' do
        expect(subject.fingerprint).to be nil
      end
    end
  end

  describe '#extra_attribute_key' do
    it 'returns a key with the type' do
      expect(subject.extra_attribute_key).to eq :back_image_fingerprint
    end
  end

  describe '#upload_key' do
    it 'returns a key with the type' do
      expect(subject.upload_key).to eq :back_image
    end
  end

  describe '#attempts_tracker_file_id_key' do
    it 'returns a key with the type' do
      expect(subject.attempts_tracker_file_id_key).to eq :document_back_image_file_id
    end
  end

  describe '#attempts_tracker_encryption_key' do
    it 'returns a key with the type' do
      expect(subject.attempts_tracker_encryption_key).to eq :document_back_image_encryption_key
    end
  end
end
