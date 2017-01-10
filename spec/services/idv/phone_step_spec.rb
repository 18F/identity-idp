require 'rails_helper'

describe Idv::PhoneStep do
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
      analytics: FakeAnalytics.new,
      params: params
    )
  end

  describe '#complete' do
    it 'returns false for invalid-looking phone' do
      step = build_step(phone: '555')

      expect(step.complete).to eq false
    end

    it 'returns true for mock-happy phone' do
      step = build_step(phone: '555-555-0000')

      expect(step.complete).to eq true
    end

    it 'returns false for mock-sad phone' do
      step = build_step(phone: '555-555-5555')

      expect(step.complete).to eq false
    end
  end

  describe '#complete?' do
    it 'returns true for mock-happy phone' do
      step = build_step(phone: '555-555-0000')
      step.complete

      expect(step.complete?).to eq true
    end

    it 'returns false for mock-sad phone' do
      step = build_step(phone: '555-555-5555')
      step.complete

      expect(step.complete?).to eq false
    end
  end
end
