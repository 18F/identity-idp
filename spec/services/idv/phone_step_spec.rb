require 'rails_helper'

describe Idv::PhoneStep do
  include Features::LocalizationHelper

  let(:user) { build(:user) }
  let(:idv_session) do
    idvs = Idv::Session.new(user_session: {}, current_user: user, issuer: nil)
    idvs.vendor = :mock
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

      result = step.submit

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
      expect(result.errors).to eq(errors)
      expect(idv_session.phone_confirmation).to eq false
    end

    it 'returns true for mock-happy phone' do
      step = build_step(phone: '555-555-0000')

      result = step.submit

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(true)
      expect(result.errors).to be_empty
      expect(idv_session.phone_confirmation).to eq true
      expect(idv_session.params).to eq idv_phone_form.idv_params
    end

    it 'returns false for mock-sad phone' do
      step = build_step(phone: '555-555-5555')

      errors = { phone: ['The phone number could not be verified.'] }

      result = step.submit

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
      expect(result.errors).to eq(errors)
      expect(idv_session.phone_confirmation).to eq false
    end
  end
end
