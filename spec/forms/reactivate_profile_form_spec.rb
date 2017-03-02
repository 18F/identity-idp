require 'rails_helper'

describe ReactivateProfileForm do
  subject(:form) do
    ReactivateProfileForm.new(user,
                              password: password)
  end

  let(:user) { build_stubbed(:user) }
  let(:recovery_code) { nil }
  let(:password) { nil }

  describe '#valid?' do
    let(:password) { 'asd' }
    let(:recovery_code) { %w(123 abc) }
    let(:valid_recovery_code?) { true }
    let(:valid_password?) { true }
    let(:recovery_code_decrypts?) { true }

    before do
      allow(form).to receive(:valid_password?).and_return(valid_password?)
      allow(form).to receive(:valid_recovery_code?).and_return(valid_recovery_code?)
      allow(form).to receive(:recovery_code_decrypts?).and_return(recovery_code_decrypts?)
    end

    context 'when required attributes are not present' do
      let(:password) { nil }
      let(:recovery_code) { nil }

      it 'is invalid' do
        expect(subject).to_not be_valid
        expect(subject.errors[:recovery_code]).to eq [t('errors.messages.blank')]
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

    context 'when recovery code does not match' do
      subject(:form) do
        ReactivateProfileForm.new(user,
                                  recovery_code: recovery_code,
                                  password: password)
      end

      let(:valid_recovery_code?) { false }

      it 'is invalid' do
        expect(subject).to_not be_valid
        expect(subject.errors[:recovery_code]).to eq [t('errors.messages.recovery_code_incorrect')]
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

      it 're-encrypts the PII and sets the recovery code in the flash' do
        recovery_code = '555'
        expect(form).to receive(:reencrypt_pii).and_return(recovery_code)

        form.submit(flash)

        expect(flash[:recovery_code]).to eq(recovery_code)
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
