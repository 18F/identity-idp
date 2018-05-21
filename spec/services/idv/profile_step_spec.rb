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

  def build_step(params, vendor_validator_result)
    idv_session.params.merge!(params)
    idv_session.applicant = idv_session.vendor_params

    described_class.new(
      idv_form_params: params,
      vendor_validator_result: vendor_validator_result,
      idv_session: idv_session
    )
  end

  describe '#submit' do
    it 'succeeds with good params' do
      messages = ['Everything looks good']
      extra = {
        idv_attempts_exceeded: false,
        vendor: { messages: messages, context: {}, exception: nil },
      }

      step = build_step(
        user_attrs,
        Idv::VendorResult.new(
          success: true,
          errors: {},
          messages: messages,
          applicant: { first_name: 'Some' }
        )
      )

      result = step.submit

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(true)
      expect(result.errors).to be_empty
      expect(result.extra).to eq(extra)
      expect(idv_session.profile_confirmation).to eq true
    end

    it 'fails with invalid SSN' do
      messages = ['The SSN was suspicious']
      errors = { ssn: ['Unverified SSN.'] }
      extra = {
        idv_attempts_exceeded: false,
        vendor: { messages: messages, context: {}, exception: nil },
      }

      step = build_step(
        user_attrs.merge(ssn: '666-66-6666'),
        Idv::VendorResult.new(success: false, errors: errors, messages: messages)
      )

      result = step.submit

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
      expect(result.errors).to eq(errors)
      expect(result.extra).to eq(extra)
      expect(idv_session.profile_confirmation).to be_nil
    end

    it 'fails with invalid first name' do
      errors = { first_name: ['Unverified first name.'] }
      messages = ['The name was suspicious']
      extra = {
        idv_attempts_exceeded: false,
        vendor: { messages: messages, context: {}, exception: nil },
      }

      step = build_step(
        user_attrs.merge(first_name: 'Bad'),
        Idv::VendorResult.new(success: false, errors: errors, messages: messages)
      )

      result = step.submit

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
      expect(result.errors).to eq(errors)
      expect(result.extra).to eq(extra)
      expect(idv_session.profile_confirmation).to be_nil
    end

    it 'fails with invalid ZIP code on current address' do
      messages = ['The ZIP code was suspicious']
      errors = { zipcode: ['Unverified ZIP code.'] }
      extra = {
        idv_attempts_exceeded: false,
        vendor: { messages: messages, context: {}, exception: nil },
      }

      step = build_step(
        user_attrs.merge(zipcode: '00000'),
        Idv::VendorResult.new(success: false, errors: errors, messages: messages)
      )

      result = step.submit

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
      expect(result.errors).to eq(errors)
      expect(result.extra).to eq(extra)
      expect(idv_session.profile_confirmation).to be_nil
    end

    it 'fails with invalid ZIP code on previous address' do
      messages = ['The ZIP code was suspicious']
      errors = { zipcode: ['Unverified ZIP code.'] }
      extra = {
        idv_attempts_exceeded: false,
        vendor: { messages: messages, context: {}, exception: nil },
      }

      step = build_step(
        user_attrs.merge(prev_zipcode: '00000'),
        Idv::VendorResult.new(success: false, errors: errors, messages: messages)
      )

      result = step.submit

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
      expect(result.errors).to eq(errors)
      expect(result.extra).to eq(extra)
      expect(idv_session.profile_confirmation).to be_nil
    end

    it 'increments attempts count' do
      step = build_step(user_attrs, Idv::VendorResult.new(errors: {}))
      expect { step.submit }.to change(user, :idv_attempts).by(1)
    end

    it 'initializes the idv_session' do
      step = build_step(user_attrs, Idv::VendorResult.new(errors: {}))
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

      step = build_step(user_attrs, Idv::VendorResult.new(errors: {}))
      expect(step.attempts_exceeded?).to eq attempter.exceeded?
    end
  end
end
