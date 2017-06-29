require 'rails_helper'

describe Idv::FinancialsStep do
  let(:user) { build(:user) }
  let(:idv_session) do
    idvs = Idv::Session.new(user_session: {}, current_user: user, issuer: nil)
    idvs.vendor = :mock
    idvs
  end
  let(:idv_finance_form) { Idv::FinanceForm.new(idv_session.params) }

  def build_step(params)
    described_class.new(
      idv_form: idv_finance_form,
      idv_session: idv_session,
      params: params
    )
  end

  describe '#submit' do
    it 'returns FormResponse with success: false for invalid params' do
      step = build_step(finance_type: :ccn, ccn: '1234')
      errors = { ccn: [t('idv.errors.invalid_ccn')] }

      result = step.submit
      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
      expect(result.errors).to eq(errors)

      expect(idv_session.financials_confirmation).to eq false
    end

    it 'returns FormResponse with success: true for mock-happy CCN' do
      step = build_step(finance_type: :ccn, ccn: '12345678')

      result = step.submit
      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(true)
      expect(result.errors).to be_empty

      expect(idv_session.financials_confirmation).to eq true
      expect(idv_session.params).to eq idv_finance_form.idv_params
    end

    it 'returns FormResponse with success: false for mock-sad CCN' do
      step = build_step(finance_type: :ccn, ccn: '00000000')

      errors = { ccn: ['The ccn could not be verified.'] }

      result = step.submit
      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
      expect(result.errors).to eq(errors)

      expect(idv_session.financials_confirmation).to eq false
    end
  end
end
