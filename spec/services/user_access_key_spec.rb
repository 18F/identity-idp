require 'rails_helper'

describe UserAccessKey do
  let(:password) { 'salty pickles' }
  let(:salt) { 'NaCL' }
  let(:ciphertext) { OpenSSL::Digest::SHA256.hexdigest('foobar') }

  subject { UserAccessKey.new(password: password, salt: salt) }

  describe '#cost' do
    it 'uses explicit scrypt cost if passed to new' do
      cost = SCrypt::Engine.calibrate(max_time: 0.2)
      uak = UserAccessKey.new(password: password, salt: salt, cost: cost)

      expect(cost).to_not eq Figaro.env.scrypt_cost
      expect(uak.z1).to_not eq subject.z1
      expect(uak.cost).to eq cost
    end
  end

  describe '#encrypted_password' do
    it 'is an alias for hash_f' do
      expect(subject.method(:encrypted_password)).to eq subject.method(:hash_f)
    end
  end

  describe '#cek' do
    it 'is an alias for hash_e' do
      expect(subject.method(:cek)).to eq subject.method(:hash_e)
    end
  end

  describe '#as_scrypt_hash' do
    it 'returns SCrypt compatible hash string' do
      expect { SCrypt::Password.new(subject.as_scrypt_hash) }.to_not raise_error
    end
  end

  describe '#hash_e' do
    it 'returns SHA256 of z2 + random_r' do
      hash_e = OpenSSL::Digest::SHA256.hexdigest(subject.z2 + subject.random_r)

      expect(subject.hash_e).to eq hash_e
    end
  end

  describe '#hash_f' do
    it 'returns SHA256 of hash_e' do
      expect(subject.hash_f).to eq OpenSSL::Digest::SHA256.hexdigest(subject.hash_e)
    end
  end

  describe '#xor' do
    it 'returns XOR of ciphertext' do
      # rubocop:disable LineLength
      expect(subject.xor(ciphertext)).to eq(
        "S\x03QR\bVV\x01\x03\a\x02\x00U\bQT\t\x00\x04\aTT\x03\t\x04\x06\x06R\x03S\b\t\x06\x05\a\r\f\x03\x01PSWU\x0E\vR\fPW[\x0F\x01V\x00\x02U\x00\x01^U\x02\a\x00P"
      )
      # rubocop:enable LineLength
    end
  end

  describe '#store_encrypted_key' do
    it 'sets the XOR value of encrypted_key' do
      subject.store_encrypted_key(ciphertext)

      expect(subject.encrypted_d).to eq subject.xor(ciphertext)
    end
  end

  describe '#encryption_key' do
    it 'returns Base64-encoded encrypted_d' do
      subject.store_encrypted_key(ciphertext)

      expect(subject.encryption_key).to eq(
        Base64.strict_encode64(subject.encrypted_d)
      )
    end
  end

  describe '#unlock' do
    it 'sets random_r' do
      subject.unlock('some random string')

      expect(subject.random_r).to eq 'some random string'
    end

    it 'returns hash_e' do
      hash_e = subject.unlock('some random string')

      expect(subject.hash_e).to eq hash_e
    end
  end

  describe '#unlocked?' do
    it 'returns true when #unlock has been called' do
      expect(subject.unlocked?).to eq false

      subject.unlock('some random string')

      expect(subject.unlocked?).to eq true
    end
  end

  describe '#made?' do
    it 'returns true when #store_encrypted_key has been called' do
      expect(subject.made?).to eq false

      subject.store_encrypted_key(ciphertext)

      expect(subject.made?).to eq true
    end
  end
end
