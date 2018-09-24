require 'rails_helper'

describe Encryption::UserAccessKey do
  let(:password) { 'this is a password' }
  let(:salt) { '1' * 64 } # hex encoded 32 random bytes
  let(:cost) { '800$8$1$' }

  let(:z1) { 'a0db7e92c1cfe24df10cc1e1dbc17831' }
  let(:z2) { '9fd0149eed6c9f42d3aa16ec23ae7317' }
  let(:scrypt_hash) { "#{cost}#{salt}$#{z1}#{z2}" }

  let(:random_r) { '1' * 32 }
  let(:encrypted_random_r) { '2' * 128 }
  let(:encryption_key) do
    'e31jSAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
    CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAlMCVlAFVwsAUQNRVFc
    ABlZUAwJRUQNXA1ZQUQMFCgED'.gsub(/\s/, '')
  end
  let(:cek) { 'a863b23a356db1619b1ae6fa565c6b6f4c6d52cdb8ec728b19306aeb9131ade5' }
  let(:encrypted_password) { '8ffa77a1504706acfcb16d67d3cf5b8dc859f6bbbde14435223d73b0a5803eb2' }

  before do
    allow(FeatureManagement).to receive(:use_kms?).and_return(true)
    # The newrelic_rpm gem added a call to `SecureRandom.hex(8)` in
    # abstract_segment.rb on 6/13/18. Our New Relic tracers in
    # config/initializers/new_relic_tracers.rb trigger this call, which
    # is why we stub with a default value first.
    allow(SecureRandom).to receive(:random_bytes) { random_r }
    allow(SecureRandom).to receive(:random_bytes).with(32).and_return(random_r)
    stub_aws_kms_client(random_r, encrypted_random_r)
  end

  subject { described_class.new(scrypt_hash: scrypt_hash) }

  describe '.new' do
    it 'allows creation of a uak using password and salt' do
      uak = described_class.new(password: password, salt: salt)

      expect(uak.cost).to eq(cost)
      expect(uak.salt).to eq(salt)
      expect(uak.z1).to eq(z1)
      expect(uak.z2).to eq(z2)
      expect(uak.as_scrypt_hash).to eq(scrypt_hash)
    end

    it 'allows creation of a uak using an scrypt hash' do
      uak = described_class.new(scrypt_hash: scrypt_hash)

      expect(uak.cost).to eq(cost)
      expect(uak.salt).to eq(salt)
      expect(uak.z1).to eq(z1)
      expect(uak.z2).to eq(z2)
      expect(uak.as_scrypt_hash).to eq(scrypt_hash)
    end

    context 'with a legacy password with a 20 byte salt' do
      # Legacy passwords had 20 bytes salts, which were SHA256 digested to get
      # to a 32 byte salt (64 char hexdigest). This test verifies that the
      # UAK behaves properly when used to verify those legacy passwords

      let(:password) { 'this is a password' }
      let(:salt) { '1' * 20 }

      let(:cost) { '800$8$1$' }
      let(:digested_salt) { 'd1b3707fbdc6a22d16e95bf6b910646f5d9c2b3ed81bd637d454ffb9bb0948e4' }
      let(:z1) { '76ad344efc442269ec28aaa28457ead2' }
      let(:z2) { '75442e6f2354b60f4f2b40de8cdc92bb' }
      let(:scrypt_hash) { "#{cost}#{digested_salt}$#{z1}#{z2}" }

      it 'can successfully create a uak using the password and the salt' do
        uak = described_class.new(password: password, salt: salt)

        expect(uak.cost).to eq(cost)
        expect(uak.z1).to eq(z1)
        expect(uak.salt).to eq(digested_salt)
        expect(uak.z2).to eq(z2)
        expect(uak.as_scrypt_hash).to eq(scrypt_hash)
      end
    end
  end

  describe '#build' do
    it 'assigns random_r and calculates the cek, encryption_key, and encrypted_password' do
      subject.build

      expect(SecureRandom).to have_received(:random_bytes).with(32).once
      expect(subject.random_r).to eq(random_r)
      expect(subject.encryption_key).to eq(encryption_key)
      expect(subject.cek).to eq(cek)
      expect(subject.encrypted_password).to eq(encrypted_password)
    end
  end

  describe '#unlock' do
    it 'derives random_r from the encryption key and sets the cek and encrypted password' do
      subject.unlock(encryption_key)

      expect(SecureRandom).to_not have_received(:random_bytes).with(32)
      expect(subject.random_r).to eq(random_r)
      expect(subject.encryption_key).to eq(encryption_key)
      expect(subject.cek).to eq(cek)
      expect(subject.encrypted_password).to eq(encrypted_password)
    end
  end

  describe '#unlocked?' do
    context 'with an initialized key' do
      it 'returns false' do
        expect(subject.unlocked?).to eq(false)
      end
    end

    context 'with a built key' do
      it 'returns true' do
        subject.build

        expect(subject.unlocked?).to eq(true)
      end
    end

    context 'with an unlocked key' do
      it 'returns true' do
        subject.unlock(encryption_key)

        expect(subject.unlocked?).to eq(true)
      end
    end
  end
end
