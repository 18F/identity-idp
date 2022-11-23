require 'rails_helper'

RSpec.describe EncryptedDocumentStorage::DocumentWriter do
  describe '#encrypt_and_write_document' do
    it 'encrypts the document and writes it to storage' do
      front_image = 'hello, i am the front image'
      back_image = 'hello, i am the back image'

      result = EncryptedDocumentStorage::DocumentWriter.new.encrypt_and_write_document(
        front_image: front_image,
        front_image_content_type: 'image/jpeg',
        back_image: back_image,
        back_image_content_type: 'image/png',
      )

      front_filename = Rails.root.join('tmp', 'encrypted_doc_storage', result.front_filename)
      back_filename = Rails.root.join('tmp', 'encrypted_doc_storage', result.back_filename)
      key = Base64.strict_decode64(result.encryption_key)

      aes_cipher = Encryption::AesCipher.new

      written_front_image = aes_cipher.decrypt(File.read(front_filename), key)
      written_back_image = aes_cipher.decrypt(File.read(back_filename), key)

      expect(written_front_image).to eq(front_image)
      expect(written_back_image).to eq(back_image)
    end
  end

  describe '#build_filename_for_content_type' do
    let(:filename) { described_class.new.build_filename_for_content_type(content_type) }
    let(:content_type) { nil }

    describe 'extension assigning' do
      subject { File.extname(filename) }

      context 'jpeg' do
        let(:content_type) { 'image/jpeg' }
        it { should eql('.jpeg') }
      end

      context 'png' do
        let(:content_type) { 'image/png' }
        it { should eql('.png') }
      end

      context 'nonsense' do
        let(:content_type) { 'yabba/dabbadoo' }
        it { should eql('') }
      end

      context nil do
        it { should eql('') }
      end
    end
  end

  describe '#storage' do
    subject { EncryptedDocumentStorage::DocumentWriter.new }

    context 'in production' do
      it 'is uses S3' do
        allow(Rails.env).to receive(:production?).and_return(true)

        expect(subject.storage).to be_a(EncryptedDocumentStorage::S3Storage)
      end
    end

    context 'outside production' do
      it 'it uses the disk' do
        allow(Rails.env).to receive(:production?).and_return(false)

        expect(subject.storage).to be_a(EncryptedDocumentStorage::LocalStorage)
      end
    end
  end
end
