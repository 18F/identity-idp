require 'rails_helper'

describe UspsConfirmationEntry do
  subject do
    described_class.new_from_hash(
      first_name: 'Some',
      last_name: 'One',
      otp: 123
    )
  end

  describe '#encrypted' do
    it 'encrypts' do
      encrypted_entry = subject.encrypted

      expect(encrypted_entry).to_not match 'Some'
    end
  end

  describe '#new_from_encrypted' do
    it 'round-trips entry' do
      encrypted_entry = subject.encrypted
      plain_entry = described_class.new_from_encrypted(encrypted_entry)

      expect(plain_entry).to eq subject
    end
  end
end
