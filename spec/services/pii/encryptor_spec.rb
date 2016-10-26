require 'rails_helper'

describe Pii::Encryptor do
  let(:plaintext) { 'four score and seven years ago' }
  subject { Pii::Encryptor.new }

  describe '#encrypt' do
    it 'returns encrypted text' do
      encrypted = subject.encrypt(plaintext)

      expect(encrypted).to_not match plaintext
    end
  end

  describe '#decrypt' do
    it 'returns original text' do
      encrypted = subject.encrypt(plaintext)

      expect(subject.decrypt(encrypted)).to eq plaintext
    end
  end
end
