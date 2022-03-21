require 'rails_helper'

RSpec.describe SessionEncryptor do
  subject { SessionEncryptor.new }
  describe '#load' do
    context 'with a legacy session ciphertext' do
      it 'decrypts the legacy session' do
        session = { 'foo' => 'bar' }

        ciphertext = LegacySessionEncryptor.new.dump(session)

        result = subject.load(ciphertext)

        expect(result).to eq(session)
      end
    end

    context 'with version 2 encryption enabled' do
      before do
        allow(IdentityConfig.store).to receive(:session_encryptor_v2_enabled).and_return(true)
      end

      it 'decrypts the new version of the session' do
        session = { 'foo' => 'bar' }

        ciphertext = SessionEncryptor.new.dump(session)

        result = subject.load(ciphertext)

        expect(result).to eq session
      end
    end
  end

  describe '#dump' do
    context 'with version 2 encryption enabled' do
      before do
        allow(IdentityConfig.store).to receive(:session_encryptor_v2_enabled).and_return(true)
      end

      it 'transparently encrypts/decrypts doc auth elements of the session' do
        session = { 'warden.user.user.session' => {
          'idv' => { 'ssn' => '666-66-6666' },
          'idv/doc_auth' => { 'ssn' => '666-66-6666' },
          'other_value' => 42,
        } }

        ciphertext = subject.dump(session)

        result = subject.load(ciphertext)
        expect(result).to eq(
          { 'warden.user.user.session' => {
            'idv' => { 'ssn' => '666-66-6666' },
            'idv/doc_auth' => { 'ssn' => '666-66-6666' },
            'other_value' => 42,
          } },
        )
      end

      it 'encrypts decrypted_pii bundle without automatically decrypting' do
        session = { 'warden.user.user.session' => {
          'decrypted_pii' => { 'ssn' => '666-66-6666' },
        } }

        ciphertext = subject.dump(session)

        result = subject.load(ciphertext)

        expect(result.fetch('warden.user.user.session')['decrypted_pii']).to eq nil
        expect(result.fetch('warden.user.user.session')['encrypted_pii']).to_not eq nil
      end

      it 'can decrypt PII bundle with Pii::Cacher' do
        session = { 'warden.user.user.session' => {
          'decrypted_pii' => { 'ssn' => '666-66-6666' },
        } }

        ciphertext = subject.dump(session)

        result = subject.load(ciphertext)
        pii_cacher = Pii::Cacher.new(nil, result.fetch('warden.user.user.session'))

        expect(result.fetch('warden.user.user.session')['decrypted_pii']).to eq nil
        expect(result.fetch('warden.user.user.session')['encrypted_pii']).to_not eq nil

        pii_cacher.fetch
        expect(JSON.parse(result.fetch('warden.user.user.session')['decrypted_pii'])).to eq(
          {
            'ssn' => '666-66-6666',
          },
        )
      end

      it 'KMS encrypts/decrypts doc auth elements of the session' do
        session = { 'warden.user.user.session' => {
          'idv' => { 'ssn' => '666-66-6666' },
          'idv/doc_auth' => { 'ssn' => '666-66-6666' },
          'other_value' => 42,
        } }

        ciphertext = subject.dump(session)

        partially_decrypted = subject.outer_encryptor.decrypt(ciphertext.split(':').last)
        partially_decrypted_json = JSON.parse(partially_decrypted)

        expect(partially_decrypted_json.fetch('warden.user.user.session')['idv']).to eq nil
        expect(partially_decrypted_json.fetch('warden.user.user.session')['idv/doc_auth']).to eq nil
        expect(
          partially_decrypted_json.fetch('warden.user.user.session')['encrypted_idv'],
        ).to_not eq nil

        expect(
          partially_decrypted_json.fetch('warden.user.user.session')['encrypted_idv/doc_auth'],
        ).to_not eq nil

        expect(
          partially_decrypted_json.fetch('warden.user.user.session')['other_value'],
        ).to eq 42
      end

      it 'KMS encrypts/decrypts doc auth elements of the session' do
        session = { 'warden.user.user.session' => {
          'idv' => { 'ssn' => '666-66-6666' },
          'idv/doc_auth' => { 'ssn' => '666-66-6666' },
          'other_value' => 42,
        } }

        ciphertext = subject.dump(session)

        partially_decrypted = subject.outer_encryptor.decrypt(ciphertext.split(':').last)
        partially_decrypted_json = JSON.parse(partially_decrypted)

        expect(partially_decrypted_json.fetch('warden.user.user.session')['idv']).to eq nil
        expect(partially_decrypted_json.fetch('warden.user.user.session')['idv/doc_auth']).to eq nil
        expect(
          partially_decrypted_json.fetch('warden.user.user.session')['encrypted_idv'],
        ).to_not eq nil

        expect(
          partially_decrypted_json.fetch('warden.user.user.session')['encrypted_idv/doc_auth'],
        ).to_not eq nil

        expect(
          partially_decrypted_json.fetch('warden.user.user.session')['other_value'],
        ).to eq 42
      end

      it 'raises if PII key appears outside of expected areas when alerting is disabled' do
        nested_session = { 'warden.user.user.session' => {
          'idv_new' => { 'nested' => { 'ssn' => '666-66-6666' } },
        } }

        nested_array_session = { 'warden.user.user.session' => {
          'idv_new' => [{ 'nested' => { 'ssn' => '666-66-6666' } }],
        } }

        expect {
          subject.dump(nested_session)
        }.to raise_error(
          SessionEncryptor::SensitiveKeyError, 'ssn unexpectedly appeared in session'
        )

        expect {
          subject.dump(nested_array_session)
        }.to raise_error(
          SessionEncryptor::SensitiveKeyError, 'ssn unexpectedly appeared in session'
        )
      end

      it 'sends alert if PII key appears outside of expected areas if alerting is enabled' do
        allow(IdentityConfig.store).to receive(:session_encryptor_alert_enabled).and_return(true)
        session = { 'warden.user.user.session' => {
          'idv_new' => { 'nested' => { 'ssn' => '666-66-6666' } },
        } }

        expect(NewRelic::Agent).to receive(:notice_error).with(
          SessionEncryptor::SensitiveKeyError.new('ssn unexpectedly appeared in session'),
          custom_params: {
            session_structure: { 'warden.user.user.session' => {
              'idv_new' => { 'nested' => { 'ssn' => nil } },
            } },
          },
        )

        subject.dump(session)
      end
    end

    context 'without version 2 encryption enabled' do
      before do
        allow(IdentityConfig.store).to receive(:session_encryptor_v2_enabled).and_return(false)
      end

      it 'encrypts the session with the legacy encryptor' do
        session = { 'foo' => 'bar' }
        ciphertext = subject.dump(session)
        decrypted_session = LegacySessionEncryptor.new.load(ciphertext)

        expect(decrypted_session).to eq(session)
      end
    end
  end
end
