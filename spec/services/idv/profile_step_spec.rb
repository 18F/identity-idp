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
    described_class.new(
      idv_form: idv_profile_form,
      idv_session: idv_session,
      analytics: FakeAnalytics.new,
      params: params
    )
  end

  describe '#complete' do
    it 'succeeds with good params' do
      step = build_step(user_attrs)

      expect(step.complete).to eq true
      expect(step.complete?).to eq true
    end

    it 'fails with invalid SSN' do
      step = build_step(user_attrs.merge(ssn: '666-66-6666'))

      expect(step.complete).to eq false
      expect(step.complete?).to eq false
    end

    it 'fails with invalid first name' do
      step = build_step(user_attrs.merge(first_name: 'Bad'))

      expect(step.complete).to eq false
      expect(step.complete?).to eq false
    end
  end

  describe '#attempts_exceeded?' do
    it 'tracks resolution attempts' do
      step = build_step(user_attrs)

      expect(step.attempts_exceeded?).to eq false

      user.idv_attempts = 3
      user.idv_attempted_at = Time.zone.now
      step = build_step(profile: user_attrs)

      expect(step.attempts_exceeded?).to eq true
    end
  end
end
