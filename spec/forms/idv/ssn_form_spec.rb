require 'rails_helper'

describe Idv::SsnForm do
  let(:user) { create(:user) }
  let(:subject) { Idv::SsnForm.new(user) }
  let(:ssn) { '111-11-1111' }

  describe '#submit' do
    context 'when the form is valid' do
      it 'returns a successful form response' do
        result = subject.submit(ssn: '111111111')

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
      end
    end

    context 'when the form is invalid' do
      it 'returns an unsuccessful form response' do
        result = subject.submit(ssn: 'abc')

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(result.errors).to include(:ssn)
      end
    end

    context 'when the form has invalid attributes' do
      it 'raises an error' do
        expect { subject.submit(ssn: '111111111', foo: 1) }.
          to raise_error(ArgumentError, 'foo is an invalid ssn attribute')
      end
    end
  end

  describe 'presence validations' do
    it 'is invalid when required attribute is not present' do
      subject.submit(ssn: nil)

      expect(subject).to_not be_valid
    end
  end

  describe 'ssn uniqueness' do
    context 'when ssn is already taken by another profile' do
      it 'is invalid' do
        diff_user = create(:user)
        create(:profile, pii: { ssn: ssn }, user: diff_user)

        subject.submit(ssn: ssn)

        expect(subject.valid?).to eq false
        expect(subject.errors[:ssn]).to eq [t('idv.errors.duplicate_ssn')]
      end

      it 'recognizes fingerprint regardless of HMAC key age' do
        diff_user = create(:user)
        create(:profile, pii: { ssn: ssn }, user: diff_user)
        rotate_hmac_key

        subject.submit(ssn: ssn)

        expect(subject.valid?).to eq false
        expect(subject.errors[:ssn]).to eq [t('idv.errors.duplicate_ssn')]
      end
    end

    context 'when ssn is already taken by same profile' do
      it 'is valid' do
        create(:profile, pii: { ssn: ssn }, user: user)

        subject.submit(ssn: ssn)

        expect(subject.valid?).to eq true
      end

      it 'recognizes fingerprint regardless of HMAC key age' do
        create(:profile, pii: { ssn: ssn }, user: user)
        rotate_hmac_key

        subject.submit(ssn: ssn)

        expect(subject.valid?).to eq true
      end
    end
  end
end
