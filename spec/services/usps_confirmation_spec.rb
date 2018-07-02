require 'rails_helper'

describe UspsConfirmation do
  let(:attributes) do
    {
      first_name: 'Homer',
      last_name: 'Simpson',
      ssn: '123-456-7890',
    }
  end
  let(:encryptor) { Encryption::Encryptors::SessionEncryptor.new }

  subject { UspsConfirmation.create!(entry: attributes) }

  describe '#entry' do
    it 'stores the entry as an encrypted json string' do
      # Since the encryption is different every time, we'll just make sure this
      # is some non-empty string thats NOT the json version of the attributes.
      expect(subject[:entry]).to be_a(String)
      expect(subject[:entry]).not_to be_empty
      expect(subject[:entry]).not_to eq(attributes.to_json)
      expect(parse(subject[:entry])).to eq(attributes)
    end

    it 'retrieves the entry as an unencrypted hash with symbolized keys' do
      expect(subject.entry).to eq(attributes)
    end
  end

  def parse(json)
    JSON.parse(encryptor.decrypt(json), symbolize_names: true)
  end
end
