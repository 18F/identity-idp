require 'rails_helper'

describe Idv::ProfileStep do
  let(:user) { create(:user) }
  let(:idv_session) { Idv::Session.new(user_session: {}, current_user: user, issuer: nil) }
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
      zipcode: '66044',
    }
  end

  def build_step(params)
    described_class.new(
      idv_form: idv_profile_form,
      idv_session: idv_session,
      params: params
    )
  end

  describe '#submit' do
    it 'succeeds with good params' do
      step = build_step(user_attrs)

      extra = {
        idv_attempts_exceeded: false,
        vendor: { reasons: ['Everything looks good'] },
      }

      result = step.submit

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(true)
      expect(result.errors).to be_empty
      expect(result.extra).to eq(extra)
      expect(idv_session.profile_confirmation).to eq true
    end

    it 'fails with invalid SSN' do
      step = build_step(user_attrs.merge(ssn: '666-66-6666'))

      errors = { ssn: ['Unverified SSN.'] }
      extra = {
        idv_attempts_exceeded: false,
        vendor: { reasons: ['The SSN was suspicious'] },
      }

      result = step.submit

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
      expect(result.errors).to eq(errors)
      expect(result.extra).to eq(extra)
      expect(idv_session.profile_confirmation).to be_nil
    end

    it 'fails when form validation fails' do
      step = build_step(user_attrs.merge(ssn: '6666'))

      errors = { ssn: [t('idv.errors.pattern_mismatch.ssn')] }
      extra = {
        idv_attempts_exceeded: false,
        vendor: { reasons: nil },
      }

      result = step.submit

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
      expect(result.errors).to eq(errors)
      expect(result.extra).to eq(extra)
      expect(idv_session.profile_confirmation).to be_nil
    end

    it 'fails with invalid first name' do
      step = build_step(user_attrs.merge(first_name: 'Bad'))

      errors = { first_name: ['Unverified first name.'] }
      extra = {
        idv_attempts_exceeded: false,
        vendor: { reasons: ['The name was suspicious'] },
      }

      result = step.submit

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
      expect(result.errors).to eq(errors)
      expect(result.extra).to eq(extra)
      expect(idv_session.profile_confirmation).to be_nil
    end

    it 'fails with invalid ZIP code on current address' do
      step = build_step(user_attrs.merge(zipcode: '00000'))

      errors = { zipcode: ['Unverified ZIP code.'] }
      extra = {
        idv_attempts_exceeded: false,
        vendor: { reasons: ['The ZIP code was suspicious'] },
      }

      result = step.submit

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
      expect(result.errors).to eq(errors)
      expect(result.extra).to eq(extra)
      expect(idv_session.profile_confirmation).to be_nil
    end

    it 'fails with invalid ZIP code on previous address' do
      step = build_step(user_attrs.merge(prev_zipcode: '00000'))

      errors = { zipcode: ['Unverified ZIP code.'] }
      extra = {
        idv_attempts_exceeded: false,
        vendor: { reasons: ['The ZIP code was suspicious'] },
      }

      result = step.submit

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
      expect(result.errors).to eq(errors)
      expect(result.extra).to eq(extra)
      expect(idv_session.profile_confirmation).to be_nil
    end

    it 'increments attempts count if the form is valid' do
      step = build_step(user_attrs)
      expect { step.submit }.to change(user, :idv_attempts).by(1)
    end

    it 'does not increment the attempts count if the form is not valid' do
      step = build_step(user_attrs.merge(ssn: '666'))
      expect { step.submit }.to change(user, :idv_attempts).by(0)
    end

    it 'initializes the idv_session' do
      step = build_step(user_attrs)
      step.submit

      expect(idv_session.params).to eq user_attrs
      expect(idv_session.applicant).to eq user_attrs.merge('uuid' => user.uuid)
    end
  end

  describe '#attempts_exceeded?' do
    it 'calls Idv::Attempter#exceeded?' do
      attempter = instance_double(Idv::Attempter)
      allow(Idv::Attempter).to receive(:new).with(user).and_return(attempter)
      allow(attempter).to receive(:exceeded?)

      step = build_step(user_attrs)
      expect(step.attempts_exceeded?).to eq attempter.exceeded?
    end
  end
end
