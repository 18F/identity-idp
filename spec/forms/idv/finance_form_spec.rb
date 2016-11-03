require 'rails_helper'

describe Idv::FinanceForm do
  subject { Idv::FinanceForm.new({}) }

  describe 'presence validations' do
    it 'is invalid when required attributes are not present' do
      valid_params = { finance_type: :ccn, finance_account: '12345678' }

      [:finance_type, :finance_account].each do |attr|
        subject.submit(valid_params.merge(attr => nil))

        expect(subject).to_not be_valid
        expect(subject.errors.full_messages.first).
          to eq "#{attr.to_s.humanize} #{t('errors.messages.blank')}"
      end
    end
  end

  describe '#submit' do
    it 'adds ccn key to idv_params when valid' do
      expect(subject.submit(finance_account: '12345678', finance_type: :ccn)).to eq true

      expected_params = {
        ccn: '12345678'
      }

      expect(subject.idv_params).to eq expected_params
    end

    it 'fails when missing all finance fields' do
      expect(subject.submit(foo: 'bar')).to eq false
    end

    context 'when CCN is not 8 digits' do
      it 'fails when alpha' do
        expect(subject.submit(finance_account: '1234567a', finance_type: :ccn)).to eq false
        expect(subject.errors[:finance_account]).to eq([t('idv.errors.invalid_ccn')])
      end

      it 'fails when long' do
        expect(subject.submit(finance_account: '123456789', finance_type: :ccn)).to eq false
        expect(subject.errors[:finance_account]).to eq([t('idv.errors.invalid_ccn')])
      end

      it 'fails when short' do
        expect(subject.submit(finance_account: '1234567', finance_type: :ccn)).to eq false
        expect(subject.errors[:finance_account]).to eq([t('idv.errors.invalid_ccn')])
      end
    end
  end
end
