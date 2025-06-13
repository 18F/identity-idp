require 'rails_helper'

RSpec.describe Idv::IdvImages do
  let(:back_image) { DocAuthImageFixtures.document_back_image_multipart }
  let(:front_image) { DocAuthImageFixtures.document_front_image_multipart }
  let(:selfie_image) { nil }
  let(:passport_image) { nil }

  let(:writer) { EncryptedDocStorage::DocWriter.new }
  let(:result) do
    EncryptedDocStorage::DocWriter::Result.new(name: 'name', encryption_key: '12345')
  end
  let(:doc_escrow_s3_storage_enabled) { false }

  let(:params) do
    {
      front: front_image,
      back: back_image,
      selfie: selfie_image,
      passport: passport_image,
    }.compact
  end

  subject(:idv_images) { described_class.new(params) }
  let(:images) { subject.images }

  describe '#initalize' do
    it 'generates the list of images based on the params' do
      expect(images.count).to eq 2
    end

    it 'makes an empty errors hash' do
      expect(subject.errors).to eq({})
    end

    it 'only includes the images represented in the params' do
      front = images.find { |image| image.type == :front }
      back = images.find { |image| image.type == :back }
      selfie = images.find { |image| image.type == :selfie }
      passport = images.find { |image| image.type == :selfie }

      expect(front).to be_a_kind_of(Idv::IdvImage)
      expect(back).to be_a_kind_of(Idv::IdvImage)
      expect(selfie).to be nil
      expect(passport).to be nil
    end
  end

  describe '#attempts_file_data' do
    before do
      allow(EncryptedDocStorage::DocWriter).to receive(:new).and_return(writer)
      allow(IdentityConfig.store).to receive(:doc_escrow_s3_storage_enabled)
        .and_return(doc_escrow_s3_storage_enabled)
      allow(writer).to receive(:write).and_return result
    end

    it 'writes the image for each given image locally' do
      expect(EncryptedDocStorage::DocWriter).to receive(:new).with(s3_enabled: false)
      expect(writer).to receive(:write).exactly(2).times

      subject.attempts_file_data
    end

    it 'returns a hash of objects' do
      expect(subject.attempts_file_data).to be_a_kind_of(Hash)
    end

    context 'when s3 storage is turned on' do
      let(:doc_escrow_s3_storage_enabled) { true }

      it 'writes the image for each given image to s3' do
        expect(EncryptedDocStorage::DocWriter).to receive(:new).with(s3_enabled: true)
        expect(writer).to receive(:write).exactly(2).times

        subject.attempts_file_data
      end
    end
  end

  describe '#submittable_images' do
    let(:front_bytes) { subject.front.bytes }
    let(:back_bytes) { subject.back.bytes }

    let(:submittable_images) do
      {
        front_image: front_bytes,
        back_image: back_bytes,
      }
    end

    it 'returns a hash of properly formatted images' do
      expect(subject.submittable_images).to eq submittable_images
    end

    context 'when an image is malformed' do
      let(:front_image) { 'not_a_url' }
      let(:front_bytes) { nil }

      it 'returns a hash of properly formatted images' do
        expect(subject.submittable_images).to eq submittable_images
      end
    end
  end

  describe '#passport_submittal' do
    context 'when there is no passport submitted' do
      it 'returns false' do
        expect(subject.passport_submittal).to be false
      end
    end

    context 'when there is a passport submitted' do
      let(:passport_image) { DocAuthImageFixtures.document_passport_image_multipart }
      it 'returns true' do
        expect(subject.passport_submittal).to be true
      end

      context 'when the passport image is malformed' do
        let(:passport_image) { 'malformed_image' }
        it 'returns true' do
          expect(subject.passport_submittal).to be true
        end
      end
    end
  end

  describe '#needed_images_present?' do
    context 'when liveness_checking is not required' do
      let(:liveness_checking_required) { false }
      context 'no passport submittal is required' do
        it 'returns an empty hash' do
          expect(subject.needed_images_present?(liveness_checking_required)).to eq({})
        end

        context 'when the back image is not submitted' do
          let(:back_image) { nil }

          it 'returns an error for the back image' do
            expect(subject.needed_images_present?(liveness_checking_required)).to eq(
              { back: { type: :blank } },
            )
          end

          context 'and the front image is not submitted' do
            let(:front_image) { nil }

            it 'returns an error for both images' do
              expect(subject.needed_images_present?(liveness_checking_required)).to eq(
                {
                  back: { type: :blank },
                  front: { type: :blank },
                },
              )
            end
          end
        end

        context 'when the front image is not submitted' do
          let(:front_image) { nil }

          it 'returns an error for the back image' do
            expect(subject.needed_images_present?(liveness_checking_required)).to eq(
              { front: { type: :blank } },
            )
          end
        end
      end

      context 'passport_submittal is required' do
        # note: passport_submittal is dependent on a passport params type, so it's not really
        # possible for it not to be present if it is necessary
        let(:passport_image) { DocAuthImageFixtures.document_passport_image_multipart }
        let(:front_image) { nil }
        let(:back_image) { nil }

        it 'returns no errors' do
          expect(subject.needed_images_present?(liveness_checking_required)).to eq({})
        end

        context 'when the passport image is malfored' do
          it 'returns no errors' do
            expect(subject.needed_images_present?(liveness_checking_required)).to eq({})
          end
        end
      end
    end

    context 'when liveness_checking is required' do
      let(:liveness_checking_required) { true }

      context 'with no selfie image' do
        it 'returns an error' do
          expect(subject.needed_images_present?(liveness_checking_required)).to eq(
            { selfie: { type: :blank } },
          )
        end
      end

      context 'with a selfie image' do
        let(:selfie_image) { DocAuthImageFixtures.selfie_image_multipart }

        it 'returns an empty hash' do
          expect(subject.needed_images_present?(liveness_checking_required)).to eq({})
        end
      end
    end
  end

  describe 'front' do
    it 'returns the front image' do
      expect(subject.front).to eq subject.images.first
    end

    context 'when there is no front image' do
      let(:front_image) { nil }
      it 'returns nil' do
        expect(subject.front).to be nil
      end
    end
  end

  describe 'back' do
    it 'returns the back image' do
      expect(subject.back).to eq subject.images.second
    end

    context 'when there is no back image' do
      let(:back_image) { nil }
      it 'returns nil' do
        expect(subject.back).to be nil
      end
    end
  end

  describe 'selfie' do
    let(:selfie_image) { DocAuthImageFixtures.selfie_image_multipart }

    it 'returns the selfie image' do
      expect(subject.selfie).to eq subject.images.last
    end

    context 'when there is no selfie image' do
      let(:selfie_image) { nil }
      it 'returns nil' do
        expect(subject.selfie).to be nil
      end
    end
  end

  describe '#write_with_data' do
    let(:image_storage_data) do
      {
        front: {
          document_front_image_file_id: 'front_name',
          document_front_image_encryption_key: Base64.strict_encode64('front_key'),
        },
        back:
        {
          document_back_image_file_id: 'back_name',
          document_back_image_encryption_key: Base64.strict_encode64('back_key'),
        },
      }
    end
    before do
      allow(EncryptedDocStorage::DocWriter).to receive(:new).and_return(writer)
      allow(IdentityConfig.store).to receive(:doc_escrow_s3_storage_enabled)
        .and_return(doc_escrow_s3_storage_enabled)
      allow(writer).to receive(:write_with_data)
    end

    it 'writes the image for each given image locally' do
      expect(EncryptedDocStorage::DocWriter).to receive(:new).with(s3_enabled: false)
      expect(writer).to receive(:write_with_data).with(
        image: subject.front.bytes,
        data: image_storage_data[:front],
      )
      expect(writer).to receive(:write_with_data).with(
        image: subject.back.bytes,
        data: image_storage_data[:back],
      )

      subject.write_with_data(image_storage_data:)
    end
  end
end
