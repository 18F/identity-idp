require 'rails_helper'

describe Idv::FinancialsStep do
  let(:user) { build(:user) }
  let(:idv_session) do
    idvs = Idv::Session.new({}, user)
    idvs.vendor = :mock
    idvs.resolution = Proofer::Resolution.new session_id: 'some-id'
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
    it 'returns false for invalid params' do
      step = build_step(finance_type: :ccn, ccn: '1234')

      result = {
        success: false,
        errors: { ccn: [t('idv.errors.invalid_ccn')] }
      }

      expect(step.submit).to eq result
      expect(idv_session.financials_confirmation).to eq false
    end

    it 'returns true for mock-happy CCN' do
      step = build_step(finance_type: :ccn, ccn: '12345678')

      result = {
        success: true,
        errors: {}
      }

      expect(step.submit).to eq result
      expect(idv_session.financials_confirmation).to eq true
      expect(idv_session.params).to eq idv_finance_form.idv_params
    end

    it 'returns false for mock-sad CCN' do
      step = build_step(finance_type: :ccn, ccn: '00000000')

      result = {
        success: false,
        errors: { ccn: ['The ccn could not be verified.'] }
      }

      expect(step.submit).to eq result
      expect(idv_session.financials_confirmation).to eq false
    end
  end
end
