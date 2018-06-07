require 'rails_helper'

describe X509::Attributes do
  let(:user_access_key) { UserAccessKey.new(password: 'sekrit', salt: SecureRandom.uuid) }

  describe '#new_from_hash' do
    it 'initializes from plain Hash' do
      x509 = described_class.new_from_hash(subject: 'O=US, OU=DoD, CN=John.Doe.1234')

      expect(x509.subject).to eq 'O=US, OU=DoD, CN=John.Doe.1234'
    end

    it 'initializes from complex Hash' do
      x509 = described_class.new_from_hash(
        subject: { raw: 'O=US, OU=DoD, CN=José', norm: 'O=US, OU=DoD, CN=Jose' },
      )

      expect(x509.subject.to_s).to eq 'O=US, OU=DoD, CN=José'
      expect(x509.subject).to be_a X509::Attribute
    end

    it 'assigns to all members' do
      x509 = described_class.new_from_hash({})

      expect(x509.subject).to be_a X509::Attribute
      expect(x509.subject.raw).to eq nil
      expect(x509.subject).to eq nil
      expect(x509.presented).to eq nil
    end
  end

  describe '#new_from_json' do
    it 'inflates from JSON string' do
      x509_json = { subject: 'O=US, OU=DoD, CN=John.Doe.1234' }.to_json
      x509_attrs = described_class.new_from_json(x509_json)

      expect(x509_attrs.subject.to_s).to eq 'O=US, OU=DoD, CN=John.Doe.1234'
    end

    it 'returns all-nil object when passed blank JSON' do
      expect(described_class.new_from_json(nil)).to be_a X509::Attributes
      expect(described_class.new_from_json('')).to be_a X509::Attributes
    end
  end
end
