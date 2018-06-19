require 'rails_helper'

describe X509::Attribute do
  let(:x509_subject) { 'O=US, OU=DoD, CN=John.Doe.1234' }

  subject { described_class.new(raw: x509_subject) }
  describe 'delegation' do
    it 'delegates to raw' do
      expect(subject.blank?).to eq false
      expect(subject.present?).to eq true
      expect(subject.to_s).to eq x509_subject
      expect(subject.to_str).to eq x509_subject
      expect(subject).to eq x509_subject
    end
  end
end
