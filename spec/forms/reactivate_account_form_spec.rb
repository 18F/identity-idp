require 'rails_helper'

describe ReactivateAccountForm do
  subject(:form) do
    ReactivateAccountForm.new(user,
                              password: password)
  end

  let(:user) { build_stubbed(:user) }
  let(:personal_key) { nil }
  let(:password) { nil }

  describe '#valid?' do
    let(:password) { 'asd' }
    let(:personal_key) { 'foo' }
    let(:valid_personal_key?) { true }
    let(:valid_password?) { true }
    let(:personal_key_decrypts?) { true }

    before do
      allow(form).to receive(:valid_password?).and_return(valid_password?)
      allow(form).to receive(:valid_personal_key?).and_return(valid_personal_key?)
      allow(form).to receive(:personal_key_decrypts?).and_return(personal_key_decrypts?)
    end

    context 'when required attributes are not present' do
      let(:password) { nil }
      let(:personal_key) { nil }

      it 'is invalid' do
        expect(subject).to_not be_valid
        expect(subject.errors[:personal_key]).to eq [t('errors.messages.blank')]
        expect(subject.errors[:password]).to eq [t('errors.messages.blank')]
      end
    end

    context 'when there is no profile that has had its password reset' do
      let(:password_reset_profile) { nil }

      it 'is invalid' do
        expect(subject).to_not be_valid
        expect(subject.errors[:base]).to eq [t('errors.messages.no_password_reset_profile')]
      end
    end

    context 'when personal key does not match' do
      subject(:form) do
        ReactivateAccountForm.new(user,
                                  personal_key: personal_key,
                                  password: password)
      end

      let(:valid_personal_key?) { false }

      it 'is invalid' do
        expect(subject).to_not be_valid
        expect(subject.errors[:personal_key]).to eq [t('errors.messages.personal_key_incorrect')]
      end
    end

    context 'when password does not match' do
      let(:valid_password?) { false }

      it 'is invalid' do
        expect(subject).to_not be_valid
        expect(subject.errors[:password]).to eq [t('errors.messages.password_incorrect')]
      end
    end
  end

  describe '#submit' do
    before { expect(form).to receive(:valid?).and_return(valid?) }

    let(:flash) { {} }

    context 'with a valid form' do
      let(:valid?) { true }

      it 're-encrypts the PII and sets the personal key in the flash' do
        personal_key = '555'
        expect(form).to receive(:reencrypt_pii).and_return(personal_key)

        form.submit(flash)

        expect(flash[:personal_key]).to eq(personal_key)
      end
    end

    context 'with an invalid form' do
      let(:valid?) { false }

      it 'clears the password' do
        form.submit(flash)

        expect(form.password).to be_nil
      end
    end
  end
end
