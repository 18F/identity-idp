require 'rails_helper'

describe Idv::FinanceForm do
  include Shoulda::Matchers::ActiveModel

  let(:params) { {} }
  subject { Idv::FinanceForm.new(params) }

  describe '.new' do
    it 'determines the finance type and finance values based on params' do
      bank_form = Idv::FinanceForm.new(
        bank_account: '12345678',
        bank_account_type: 'checking',
        bank_routing: '87654321'
      )
      expect(bank_form.finance_type).to eq('bank_account')
      expect(bank_form.bank_account).to eq('12345678')
      expect(bank_form.bank_account_type).to eq('checking')
      expect(bank_form.bank_routing).to eq('87654321')

      auto_loan_form = Idv::FinanceForm.new(auto_loan: '12345678')

      expect(auto_loan_form.finance_type).to eq('auto_loan')
      expect(auto_loan_form.auto_loan).to eq('12345678')

      invalid_type_form = Idv::FinanceForm.new(asdf: '12345678')
      expect(invalid_type_form.finance_type).to eq(nil)
    end
  end

  describe 'validations' do
    it {
      should validate_inclusion_of(:finance_type).
        in_array(Idv::FinanceForm::FINANCE_TYPES).
        with_message(I18n.t('idv.errors.missing_finance'))
    }

    context 'bank_account finance type' do
      let(:params) do
        {
          finance_type: 'bank_account',
          bank_account: '12345678',
          bank_routing: '123456789',
          bank_account_type: 'checking',
        }
      end

      it { expect(subject).to be_valid }

      it { should validate_presence_of(:bank_account) }
      it {
        should validate_length_of(:bank_account).
          is_at_least(8).
          is_at_most(30).
          with_message(
            I18n.t(
              'idv.errors.finance_number_length',
              minimum: 8,
              maximum: 30
            )
          )
      }
      it { should_validate_not_alpha(:bank_account) }
      it { should validate_presence_of(:bank_routing) }
      it { should validate_length_of(:bank_routing).is_equal_to(9) }
      it { should_validate_not_alpha(:bank_routing) }
      it { should validate_inclusion_of(:bank_account_type).in_array(%w[checking savings]) }
    end

    context 'ccn finance type' do
      let(:params) { { finance_type: 'ccn', ccn: '12345678' } }

      it { expect(subject).to be_valid }
      it { should validate_presence_of(:ccn) }
      it { should validate_length_of(:ccn).is_equal_to(8) }
      it { should_validate_not_alpha(:ccn) }
    end

    Idv::FinanceForm::OTHER_FINANCE_TYPES.each do |finance_type|
      context "#{finance_type} finance_type" do
        let(:params) { { finance_type: finance_type.to_s, finance_type => '12345678' } }

        it { expect(subject).to be_valid }
        it { should validate_presence_of(finance_type) }
        it {
          should validate_length_of(finance_type).
            is_at_least(8).
            is_at_most(30).
            with_message(
              I18n.t(
                'idv.errors.finance_number_length',
                minimum: 8,
                maximum: 30
              )
            )
        }
        it { should_validate_not_alpha(finance_type) }
      end
    end

    def should_validate_not_alpha(attribute)
      subject.send("#{attribute}=", '12345678a')

      expect(subject).to be_invalid
      expect(subject.errors).to include(attribute)
    end
  end

  describe '#submit(params)' do
    it 'updates the attributes with the params' do
      subject = Idv::FinanceForm.new(finance_type: 'ccn', ccn: '12345678')
      subject.submit(finance_type: 'auto_loan', auto_loan: '0987654321')

      expect(subject.finance_type).to eq('auto_loan')
      expect(subject.auto_loan).to eq('0987654321')
      expect(subject.ccn).to eq(nil)
    end

    context 'with valid params' do
      let(:params) { { finance_type: 'ccn', ccn: '12345678' } }
      it 'returns a successful form response' do
        response = subject.submit(params)

        expect(response).to be_kind_of(FormResponse)
        expect(response.success?).to eq(true)
        expect(response.errors).to be_empty
      end
    end

    context 'with invalid params' do
      it 'returns an unsuccessful form response' do
        response = subject.submit(these: 'are', garbage: 'params')

        expect(response).to be_kind_of(FormResponse)
        expect(response.success?).to eq(false)
        expect(response.errors).to_not be_empty
      end
    end
  end

  describe '#idv_params' do
    context 'bank_account finance type' do
      let(:params) do
        {
          finance_type: 'bank_account',
          bank_account: '12345678',
          bank_account_type: 'checking',
          bank_routing: '987654321',
        }
      end

      it 'returns bank_account params' do
        expect(subject.idv_params).to eq(
          bank_account: '12345678',
          bank_account_type: 'checking',
          bank_routing: '987654321'
        )
      end
    end

    (Idv::FinanceForm::FINANCE_TYPES - %w[bank_account]).each do |finance_type|
      context "#{finance_type} finance type" do
        let(:params) { { finance_type: finance_type, finance_type.to_sym => '12345678' } }

        it "returns #{finance_type} params" do
          expect(subject.idv_params).to eq(
            finance_type.to_sym => '12345678'
          )
        end
      end
    end
  end
end
