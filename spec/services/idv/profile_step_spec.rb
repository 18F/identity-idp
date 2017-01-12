require 'rails_helper'

describe Idv::ProfileStep do
  let(:user) { create(:user) }
  let(:idv_session) { Idv::Session.new({}, user) }
  let(:idv_profile_form) { Idv::ProfileForm.new(idv_session.params, user) }
  let(:user_attrs) do
    {
      first_name: 'Some',
      last_name: 'One',
      ssn: '666-66-1234',
      dob: '19720329',
      address1: '123 Main St',
      address2: '',
      city: 'Somewhere',
      state: 'KS',
      zipcode: '66044'
    }
  end

  def build_step(params)
    @analytics = FakeAnalytics.new
    allow(@analytics).to receive(:track_event)

    described_class.new(
      idv_form: idv_profile_form,
      idv_session: idv_session,
      analytics: @analytics,
      params: params
    )
  end

  def expect_analytics_result(result)
    expect(@analytics).to have_received(:track_event).
      with(Analytics::IDV_BASIC_INFO_SUBMITTED, result)
  end

  describe '#complete' do
    it 'succeeds with good params' do
      step = build_step(user_attrs)

      expect(step.complete).to eq true
      expect(step.complete?).to eq true

      result = {
        success: true,
        idv_attempts_exceeded: false,
        errors: {}
      }

      expect_analytics_result(result)
    end

    it 'fails with invalid SSN' do
      step = build_step(user_attrs.merge(ssn: '666-66-6666'))

      expect(step.complete).to eq false
      expect(step.complete?).to eq false

      result = {
        success: false,
        idv_attempts_exceeded: false,
        errors: {
          ssn: ['Unverified SSN.']
        }
      }

      expect_analytics_result(result)
    end

    it 'fails with invalid first name' do
      step = build_step(user_attrs.merge(first_name: 'Bad'))

      expect(step.complete).to eq false
      expect(step.complete?).to eq false

      result = {
        success: false,
        idv_attempts_exceeded: false,
        errors: {
          first_name: ['Unverified first name.']
        }
      }

      expect_analytics_result(result)
    end
  end

  describe '#attempts_exceeded?' do
    it 'tracks resolution attempts' do
      user.idv_attempts = 3
      user.idv_attempted_at = Time.zone.now
      step = build_step(user_attrs)

      step.complete
      expect(step.attempts_exceeded?).to eq true

      result = {
        success: false,
        idv_attempts_exceeded: true,
        errors: {}
      }

      expect_analytics_result(result)
    end
  end
end
