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
    @analytics = FakeAnalytics.new
    allow(@analytics).to receive(:track_event)

    described_class.new(
      idv_form: idv_phone_form,
      idv_session: idv_session,
      analytics: @analytics,
      params: params
    )
  end

  def expect_analytics_result(result)
    expect(@analytics).to have_received(:track_event).with(
      Analytics::IDV_PHONE_CONFIRMATION, result
    )
  end

  describe '#complete' do
    it 'returns false for invalid-looking phone' do
      step = build_step(phone: '555')

      expect(step.complete).to eq false

      result = {
        success: false,
        errors: {
          phone: [invalid_phone_message]
        }
      }

      expect_analytics_result(result)
    end

    it 'returns true for mock-happy phone' do
      step = build_step(phone: '555-555-0000')

      expect(step.complete).to eq true

      result = {
        success: true,
        errors: {}
      }

      expect_analytics_result(result)
    end

    it 'returns false for mock-sad phone' do
      step = build_step(phone: '555-555-5555')

      expect(step.complete).to eq false

      result = {
        success: false,
        errors: {
          phone: ['The phone number could not be verified.']
        }
      }

      expect_analytics_result(result)
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
