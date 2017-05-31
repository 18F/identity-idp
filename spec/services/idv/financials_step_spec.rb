require 'rails_helper'

describe Idv::FinancialsStep do
  let(:user) { build(:user) }
  let(:idv_session) do
    idvs = Idv::Session.new({}, user)
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
      extra = { vendor: { reasons: nil } }
      errors = { ccn: [t('idv.errors.invalid_ccn')] }

      response = instance_double(FormResponse)
      allow(FormResponse).to receive(:new).and_return(response)
      submission = step.submit

      expect(submission).to eq response
      expect(FormResponse).to have_received(:new).
        with(success: false, errors: errors, extra: extra)
      expect(idv_session.financials_confirmation).to eq false
    end

    it 'returns FormResponse with success: true for mock-happy CCN' do
      step = build_step(finance_type: :ccn, ccn: '12345678')
      extra = { vendor: { reasons: ['Good number'] } }

      response = instance_double(FormResponse)
      allow(FormResponse).to receive(:new).and_return(response)

      submission = step.submit

      expect(submission).to eq response
      expect(FormResponse).to have_received(:new).
        with(success: true, errors: {}, extra: extra)
      expect(idv_session.financials_confirmation).to eq true
      expect(idv_session.params).to eq idv_finance_form.idv_params
    end

    it 'returns FormResponse with success: false for mock-sad CCN' do
      step = build_step(finance_type: :ccn, ccn: '00000000')

      extra = { vendor: { reasons: ['Bad number'] } }
      errors = { ccn: ['The ccn could not be verified.'] }

      response = instance_double(FormResponse)
      allow(FormResponse).to receive(:new).and_return(response)
      submission = step.submit

      expect(submission).to eq response
      expect(FormResponse).to have_received(:new).
        with(success: false, errors: errors, extra: extra)
      expect(idv_session.financials_confirmation).to eq false
    end
  end
end
