require 'rails_helper'

RSpec.xdescribe FileEncryptor do
  let(:email) { Figaro.env.equifax_gpg_email }

  subject(:file_encryptor) do
    FileEncryptor.new(
      Rails.root.join('keys', 'equifax_gpg.pub.bin'),
      email
    )
  end

  let(:output_file) { Tempfile.new('temp.encrypted') }

  after do
    output_file.close
    output_file.unlink
  end

  describe '#encrypt' do
    let(:plaintext) { 'aaa' }

    subject(:encrypt) { file_encryptor.encrypt(plaintext, output_file.path) }

    it 'writes the encrypted content to a file' do
      encrypt

      encrypted_content = File.binread(output_file.path)

      expect(encrypted_content).to be_present
      expect(encrypted_content).to_not include(plaintext)
    end

    context 'with a bad email' do
      let(:email) { 'aaa@aaa.com' }

      it 'raises an error' do
        expect { encrypt }.to raise_error(FileEncryptor::EncryptionError)
      end
    end
  end

  describe '#decrypt' do
    let(:passphrase) { Figaro.env.equifax_development_example_gpg_passphrase }
    let(:plaintext) { 'some super secret content' }

    before do
      file_encryptor.encrypt(plaintext, output_file.path)
    end

    it 'returns the decrypted content' do
      decrypted = file_encryptor.decrypt(passphrase, output_file.path)

      expect(decrypted).to eq(plaintext)
    end
  end
end
