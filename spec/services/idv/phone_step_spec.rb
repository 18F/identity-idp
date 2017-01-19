require 'rails_helper'

describe Idv::PhoneStep do
  include Features::LocalizationHelper

  let(:user) { build(:user) }
  let(:idv_session) do
    idvs = Idv::Session.new({}, user)
    idvs.vendor = :mock
    idvs.resolution = Proofer::Resolution.new session_id: 'some-id'
    idvs.applicant = Proofer::Applicant.new first_name: 'Some'
    idvs
  end
  let(:idv_phone_form) { Idv::PhoneForm.new(idv_session.params, user) }

  def build_step(params)
    described_class.new(
      idv_form: idv_phone_form,
      idv_session: idv_session,
      params: params
    )
  end

  describe '#submit' do
    it 'returns false for invalid-looking phone' do
      step = build_step(phone: '555')

      errors = { phone: [invalid_phone_message] }

      result = instance_double(FormResponse)

      expect(FormResponse).to receive(:new).
        with(success: false, errors: errors).and_return(result)
      expect(step.submit).to eq result
      expect(idv_session.phone_confirmation).to eq false
    end

    it 'returns true for mock-happy phone' do
      step = build_step(phone: '555-555-0000')

      result = instance_double(FormResponse)

      expect(FormResponse).to receive(:new).with(success: true, errors: {}).
        and_return(result)
      expect(step.submit).to eq result
      expect(idv_session.phone_confirmation).to eq true
      expect(idv_session.params).to eq idv_phone_form.idv_params
      expect(idv_session.applicant.phone).to eq idv_phone_form.phone
    end

    it 'returns false for mock-sad phone' do
      step = build_step(phone: '555-555-5555')

      errors = { phone: ['The phone number could not be verified.'] }

      result = instance_double(FormResponse)

      expect(FormResponse).to receive(:new).
        with(success: false, errors: errors).and_return(result)
      expect(step.submit).to eq result
      expect(idv_session.phone_confirmation).to eq false
    end
  end
end
