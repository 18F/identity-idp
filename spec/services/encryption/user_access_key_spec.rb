require 'rails_helper'

describe Encryption::UserAccessKey do
  let(:password) { 'this is a password' }
  let(:password_salt) { 'this is a salt' }

  let(:cost) { '800$8$1$' }
  let(:scrypt_salt) { 'bd305e29843227105aa7c820ddef8e2a6b4c88831abd84a8702370d401b44245' }
  let(:z1) { '0a9bcfee214c15a6bbafef7204a0af88' }
  let(:z2) { '8747755bcd92f295330e438059163eb1' }
  let(:scrypt_hash) { "#{cost}#{scrypt_salt}$#{z1}#{z2}" }

  let(:random_r) { '1' * 32 }
  let(:encrypted_random_r) { '2' * 128 }
  let(:encryption_key) do
    'e31jSAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
    CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgJTC1BRVFdXAAMGUQM
    HUwRQUFNUV1QFAAIGUwJTVAoK'.gsub(/\s/, '')
  end
  let(:cek) { '7374ebc97ba0f2b7a38b03fd76b2faafadded15c78c16dafaa0cf8e5e4740ff5' }
  let(:encrypted_password) { '2e1ec56ad48694902e0b96d0979135363c14bd443707200c931358849bcb0a94' }

  before do
    allow(FeatureManagement).to receive(:use_kms?).and_return(true)
    allow(SecureRandom).to receive(:random_bytes).with(32).and_return(random_r)
    stub_aws_kms_client(random_r, encrypted_random_r)
  end

  subject { described_class.new(scrypt_hash: scrypt_hash) }

  describe '.new' do
    it 'allows creation of a uak using password and salt' do
      uak = described_class.new(password: password, salt: password_salt)

      expect(uak.cost).to eq(cost)
      expect(uak.salt).to eq(scrypt_salt)
      expect(uak.z1).to eq(z1)
      expect(uak.z2).to eq(z2)
      expect(uak.as_scrypt_hash).to eq(scrypt_hash)
    end

    it 'allows creation of a uak using an scrypt hash' do
      uak = described_class.new(scrypt_hash: scrypt_hash)

      expect(uak.cost).to eq(cost)
      expect(uak.salt).to eq(scrypt_salt)
      expect(uak.z1).to eq(z1)
      expect(uak.z2).to eq(z2)
      expect(uak.as_scrypt_hash).to eq(scrypt_hash)
    end
  end

  describe '#build' do
    it 'assigns random_r and calculates the cek, encryption_key, and encrypted_password' do
      subject.build

      expect(SecureRandom).to have_received(:random_bytes).once
      expect(subject.random_r).to eq(random_r)
      expect(subject.encryption_key).to eq(encryption_key)
      expect(subject.cek).to eq(cek)
      expect(subject.encrypted_password).to eq(encrypted_password)
    end
  end

  describe '#unlock' do
    it 'derives random_r from the encryption key and sets the cek and encrypted password' do
      subject.unlock(encryption_key)

      expect(SecureRandom).to_not have_received(:random_bytes)
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
