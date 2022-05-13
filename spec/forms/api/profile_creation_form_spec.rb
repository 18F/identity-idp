require 'rails_helper'

RSpec.describe Api::ProfileCreationForm do
  let(:password) { 'salty pickles' }
  let(:entered_password) { password }
  let(:user) { create(:user, password: password) }
  let(:uuid) { user.uuid }
  let(:pii) do
    { first_name: 'Ada', last_name: 'Lovelace', ssn: '900-90-0900' }
  end
  let(:metadata) { {} }
  let(:key) { OpenSSL::PKey::RSA.new(Base64.strict_decode64(IdentityConfig.store.idv_private_key)) }
  let(:bundle) do
    JWT.encode({ pii: pii, metadata: metadata }, key, 'RS256', sub: uuid.to_s)
  end
  let(:user_session) { {} }

  subject do
    Api::ProfileCreationForm.new(
      password: entered_password,
      jwt: bundle,
      user_session: user_session,
    )
  end

  describe '#submit' do
    context 'with the correct password' do
      it 'returns a successful response with the personal_key in the extra hash' do
        response, personal_key = subject.submit

        expect(response.success?).to be true
        expect(personal_key).to be_present
      end

      it 'creates and saves the user profile' do
        expect(user.profiles.count).to eq 0

        subject.submit

        expect(user.profiles.count).to eq 1
      end

      it 'saves the user pii encrypted with their password in the profile' do
        subject.submit
        profile = user.profiles.first
        decrypted_pii = profile.decrypt_pii(password)

        expect(decrypted_pii[:first_name]).to eq 'Ada'
      end

      it 'saves the user pii encrypted with their personal_key in the profile' do
        _response, key = subject.submit
        profile = user.profiles.first
        personal_key = PersonalKeyGenerator.new(user).normalize(key)
        decrypted_recovery_pii = profile.recover_pii(personal_key)

        expect(decrypted_recovery_pii[:first_name]).to eq 'Ada'
      end

      context 'with the user having verified their phone' do
        let(:metadata) do
          {
            vendor_phone_confirmation: true,
            user_phone_confirmation: true,
          }
        end

        it 'activates the user profile' do
          subject.submit
          profile = user.profiles.first

          expect(profile.active?).to be true
        end

        it 'moves the pii to the user_session' do
          subject.submit
          stored_pii = JSON.parse(user_session[:decrypted_pii])

          expect(stored_pii['first_name']).to eq 'Ada'
        end
      end

      context 'with the user having verified their address via GPO letter' do
        let(:metadata) do
          {
            address_verification_mechanism: 'gpo',
          }
        end

        it 'does not activate the user profile' do
          subject.submit
          profile = user.profiles.first

          expect(profile.active?).to be false
        end

        it 'moves the pii to the user_session' do
          subject.submit
          stored_pii = JSON.parse(user_session[:decrypted_pii])

          expect(stored_pii['first_name']).to eq 'Ada'
        end

        it 'creates a GPO confirmation code' do
          subject.submit
          profile = user.profiles.first
          gpo_otp = GpoConfirmation.last.entry[:otp]

          expect(profile.gpo_confirmation_codes.first_with_otp(gpo_otp)).not_to be_nil
        end
      end
    end

    context 'with an incorrect password' do
      let(:entered_password) { 'wild guess' }

      it 'returns an unsuccessful response with an error about the password' do
        response, personal_key = subject.submit

        expect(response.success?).to be false
        expect(personal_key).to be_nil
        expect(response.errors[:password]).to eq [I18n.t('idv.errors.incorrect_password')]
      end
    end

    context 'with a non-existent user' do
      let(:uuid) { SecureRandom.uuid }

      it 'returns an unsuccessful response with an error about the user' do
        response, personal_key = subject.submit

        expect(response.success?).to be false
        expect(personal_key).to be_nil
        expect(response.errors[:user]).to eq [I18n.t('devise.failure.unauthenticated')]
      end
    end

    context 'with an expired JWT' do
      let(:bundle) { JWT.encode(pii.merge(exp: 1.day.ago.to_i), key, 'RS256', sub: uuid.to_s) }

      it 'returns an unsuccessful response with an error about the jwt' do
        response, personal_key = subject.submit

        expect(response.success?).to be false
        expect(personal_key).to be_nil
        expect(response.errors[:jwt]).to eq [I18n.t('idv.failure.exceptions.internal_error')]
      end
    end
  end

  describe '#valid?' do
    context 'with the correct password' do
      it 'is a valid form' do
        expect(subject.valid?).to be true
      end
    end

    context 'with an incorrect password' do
      let(:entered_password) { 'wild guess' }

      it 'is an invalid form' do
        expect(subject.valid?).to be false
      end
    end

    context 'with a non-existent user' do
      let(:uuid) { SecureRandom.uuid }

      it 'is an invalid form' do
        expect(subject.valid?).to be false
      end
    end

    context 'with an expired JWT' do
      let(:bundle) do
        JWT.encode(
          { pii: pii, metadata: metadata, exp: 1.day.ago.to_i },
          key,
          'RS256',
          sub: uuid,
        )
      end

      it 'is an invalid form' do
        expect(subject.valid?).to be false
        expect(subject.errors[:jwt]).to eq [I18n.t('idv.failure.exceptions.internal_error')]
        expect(subject.errors).to include { |error| error.options[:type] == :decode_error }
      end
    end

    context 'with a JWT missing pii' do
      let(:bundle) do
        JWT.encode(
          { metadata: metadata },
          key,
          'RS256',
          sub: uuid,
        )
      end

      it 'is an invalid form' do
        expect(subject.valid?).to be false
        expect(subject.errors[:jwt]).to eq [I18n.t('idv.failure.exceptions.internal_error')]
        expect(subject.errors).to include { |error| error.options[:type] == :user_bundle_error }
      end
    end

    context 'with a JWT missing metadata' do
      let(:bundle) do
        JWT.encode(
          { pii: pii },
          key,
          'RS256',
          sub: uuid,
        )
      end

      it 'is an invalid form' do
        expect(subject.valid?).to be false
        expect(subject.errors[:jwt]).to eq [I18n.t('idv.failure.exceptions.internal_error')]
        expect(subject.errors).to include { |error| error.options[:type] == :user_bundle_error }
      end
    end
  end
end
