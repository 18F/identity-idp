require 'rails_helper'

describe SessionEncryptor do
  describe '#load' do
    it 'decrypts encrypted session' do
      session = SessionEncryptor.dump(foo: 'bar')

      expect(SessionEncryptor.load(session)).to eq('foo' => 'bar')
    end
  end

  describe '#dump' do
    it 'encrypts session' do
      session = SessionEncryptor.dump(foo: 'bar')

      expect(session).to_not match 'foo'
      expect(session).to_not match 'bar'
    end
  end

  describe '#encryptor' do
    it 'is a Pii::Encryptor' do
      expect(SessionEncryptor.encryptor).to be_a Pii::Encryptor
    end
  end
end
