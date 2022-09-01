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

      it 'transparently encrypts/decrypts sensitive elements of the session' do
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
          'decrypted_pii' => { 'ssn' => '666-66-6666' }.to_json,
        } }

        ciphertext = subject.dump(session)

        result = subject.load(ciphertext)

        expect(result.fetch('warden.user.user.session')['decrypted_pii']).to eq nil
        expect(result.fetch('warden.user.user.session')['encrypted_pii']).to_not eq nil
      end

      it 'can decrypt PII bundle with Pii::Cacher' do
        session = { 'warden.user.user.session' => {
          'decrypted_pii' => { 'ssn' => '666-66-6666' }.to_json,
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

        partially_decrypted = subject.outer_decrypt(ciphertext.split(':').last)
        partially_decrypted_json = JSON.parse(partially_decrypted)

        expect(partially_decrypted_json.fetch('warden.user.user.session')['idv']).to eq nil
        expect(partially_decrypted_json.fetch('warden.user.user.session')['idv/doc_auth']).to eq nil
        expect(
          partially_decrypted_json.fetch('sensitive_data'),
        ).to_not eq nil

        expect(
          partially_decrypted_json.fetch('warden.user.user.session')['other_value'],
        ).to eq 42
      end

      it 'raises if reserved key is used' do
        session = {
          'sensitive_data' => 'test',
          'warden.user.user.session' => {
            'other_value' => 42,
          },
        }

        expect do
          subject.dump(session)
        end.to raise_error(
          RuntimeError, "invalid session, 'sensitive_data' is reserved key"
        )
      end

      it 'raises if PII key appears outside of expected areas when alerting is disabled' do
        nested_session = { 'warden.user.user.session' => {
          'idv_new' => { 'nested' => { 'ssn' => '666-66-6666' } },
        } }

        nested_array_session = { 'warden.user.user.session' => {
          'idv_new' => [{ 'nested' => { 'ssn' => '666-66-6666' } }],
        } }

        expect do
          subject.dump(nested_session)
        end.to raise_error(
          SessionEncryptor::SensitiveKeyError, 'ssn unexpectedly appeared in session'
        )

        expect do
          subject.dump(nested_array_session)
        end.to raise_error(
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
              'idv_new' => { 'nested' => { 'ssn' => '' } },
            } },
          },
        )

        subject.dump(session)
      end

      it 'raises if sensitive value is not KMS encrypted' do
        session = {
          'new_key' => Idp::Constants::MOCK_IDV_APPLICANT[:last_name],
        }

        expect do
          subject.dump(session)
        end.to raise_error(
          SessionEncryptor::SensitiveValueError,
        )
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

  describe '#kms_encrypt_sensitive_paths!' do
    it 'encrypts/decrypts transparently' do
      sensitive_paths = [
        ['a'],
        ['1', '2', '3'],
      ]

      original_session = {
        'unencrypted' => 0,
        'a' => 414,
        '1' => {
          '2' => {
            '3' => 34,
          },
        },
      }

      session = original_session.deep_dup
      SessionEncryptor.new.send(:kms_encrypt_sensitive_paths!, session, sensitive_paths)

      expect(session['unencrypted']).to eq 0
      expect(session.key?('a')).to eq false
      expect(session.dig('1', '2').key?('3')).to eq false

      SessionEncryptor.new.send(:kms_decrypt_sensitive_paths!, session)

      expect(session).to eq original_session
    end
  end
end
