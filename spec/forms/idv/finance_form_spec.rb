require 'rails_helper'

describe Idv::FinanceForm do
  subject { Idv::FinanceForm.new({}) }

  describe 'presence validations' do
    it 'is invalid when required attributes are not present' do
      valid_params = { finance_type: :mortgage, mortgage: 'abc123' }

      [:finance_type, :mortgage].each do |attr|
        subject.submit(valid_params.merge(attr => nil))

        expect(subject).to_not be_valid
        expect(subject.errors.full_messages.first).
          to eq "#{attr.to_s.humanize} #{t('errors.messages.blank')}"
      end
    end

    it 'is valid when required attributes are present' do
      valid_params = { finance_type: :mortgage, mortgage: 'abcd1234' }
      subject.submit(valid_params)

      expect(subject).to be_valid
    end
  end

  describe '#submit' do
    it 'adds ccn key to idv_params when valid' do
      expect(subject.submit(ccn: '12345678', finance_type: :ccn)).to eq true

      expected_params = {
        ccn: '12345678'
      }

      expect(subject.idv_params).to eq expected_params
    end

    it 'fails when missing all finance fields' do
      expect(subject.submit(foo: 'bar')).to eq false
    end

    context 'when CCN is invalid' do
      it 'fails when alpha' do
        expect(subject.submit(ccn: '1234567a', finance_type: :ccn)).to eq false
        expect(subject.errors[:ccn]).to eq([t('idv.errors.invalid_ccn')])
      end

      it 'fails when long' do
        expect(subject.submit(ccn: '123456789', finance_type: :ccn)).to eq false
        expect(subject.errors[:ccn]).to eq([t('idv.errors.invalid_ccn')])
      end

      it 'fails when short' do
        expect(subject.submit(ccn: '1234567', finance_type: :ccn)).to eq false
        expect(subject.errors[:ccn]).to eq([t('idv.errors.invalid_ccn')])
      end
    end

    context 'any non-ccn financial value is less than the minimum allowed digits' do
      it 'fails' do
        finance_types = Idv::FinanceForm::FINANCE_TYPES
        short_value = '1' * (FormFinanceValidator::VALID_MINIMUM_LENGTH - 1)

        finance_types.each do |type|
          next if type == :ccn
          params = { type => short_value, finance_type: type }

          expect(subject.submit(params)).to eq false
          expect(subject.errors[type]).to eq([t(
            'idv.errors.finance_number_length',
            minimum: FormFinanceValidator::VALID_MINIMUM_LENGTH,
            maximum: FormFinanceValidator::VALID_MAXIMUM_LENGTH
          )])
        end
      end
    end

    context 'any non-ccn financial value is over the max allowed digits' do
      it 'fails' do
        finance_types = Idv::FinanceForm::FINANCE_TYPES
        long_value = '1' * (FormFinanceValidator::VALID_MAXIMUM_LENGTH + 1)

        finance_types.each do |type|
          next if type == :ccn
          symbolized_type = type.to_sym
          params = {
            symbolized_type => long_value,
            finance_type: symbolized_type
          }

          expect(subject.submit(params)).to eq false
          expect(subject.errors[symbolized_type]).to eq([t(
            'idv.errors.finance_number_length',
            minimum: FormFinanceValidator::VALID_MINIMUM_LENGTH,
            maximum: FormFinanceValidator::VALID_MAXIMUM_LENGTH
          )])
        end
      end
    end
  end
end
