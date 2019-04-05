require 'rails_helper'

describe Idv::ProfileStep do
  let(:user) { create(:user) }
  let(:idv_session) { Idv::Session.new(user_session: {}, current_user: user, issuer: nil) }
  let(:user_attrs) do
    {
      first_name: 'Some',
      last_name: 'One',
      ssn: '666-66-1234',
      dob: '19720329',
      address1: '123 Main St',
      address2: '',
      city: 'Somewhere',
      state: 'VA',
      zipcode: '66044',
      state_id_jurisdiction: 'VA',
      state_id_number: '123abc',
      state_id_type: 'drivers_license',
    }
  end

  subject { described_class.new(idv_session: idv_session) }

  describe '#submit' do
    it 'succeeds with good params' do
      context = { stages: [{ resolution: 'ResolutionMock' }, { state_id: 'StateIdMock' }] }
      extra = {
        idv_attempts_exceeded: false,
        vendor: { messages: [], context: context, exception: nil, timed_out: false },
        ssn_is_unique: true,
      }

      result = subject.submit(user_attrs)

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(true)
      expect(result.errors).to be_empty
      expect(result.extra).to eq(extra)
      expect(idv_session.profile_confirmation).to eq true
      expect(idv_session.resolution_successful).to eq true
      expect(idv_session.applicant).to eq(user_attrs.merge(uuid: user.uuid))
    end

    it 'fails with bad params' do
      user_attrs[:ssn] = '666-66-6666'

      context = { stages: [{ resolution: 'ResolutionMock' }] }
      errors = { ssn: ['Unverified SSN.'] }
      extra = {
        idv_attempts_exceeded: false,
        vendor: { messages: [], context: context, exception: nil, timed_out: false },
        ssn_is_unique: true,
      }

      result = subject.submit(user_attrs)

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
      expect(result.errors).to eq(errors)
      expect(result.extra).to eq(extra)
      expect(idv_session.profile_confirmation).to be_nil
      expect(idv_session.resolution_successful).to be_nil
      expect(idv_session.applicant).to be_nil
    end

    it 'increments attempts count' do
      expect { subject.submit(user_attrs) }.to change(user, :idv_attempts).by(1)
    end

    it 'does not increment attempts count when the vendor request times out' do
      expect { subject.submit(user_attrs.merge(first_name: 'Time')) }.
        to_not change(user, :idv_attempts)
    end

    it 'does not increment attempts count when the vendor raises an exception' do
      expect { subject.submit(user_attrs.merge(first_name: 'Fail')) }.
        to_not change(user, :idv_attempts)
    end
  end

  describe '#failure_reason' do
    context 'when there are idv attempts remaining' do
      it 'returns :warning' do
        subject.submit(user_attrs.merge(first_name: 'Bad'))

        expect(subject.failure_reason).to eq(:warning)
      end
    end

    context 'when there are not idv attempts remaining' do
      it 'returns :fail' do
        user.update(idv_attempts: Idv::Attempter.idv_max_attempts - 1)

        subject.submit(user_attrs.merge(first_name: 'Bad'))

        expect(subject.failure_reason).to eq(:fail)
      end
    end

    context 'when the vendor raises a timeout exception' do
      it 'returns :timeout' do
        subject.submit(user_attrs.merge(first_name: 'Time'))

        expect(subject.failure_reason).to eq(:timeout)
      end
    end

    context 'when the vendor raises an exception' do
      it 'returns :jobfail' do
        subject.submit(user_attrs.merge(first_name: 'Fail'))

        expect(subject.failure_reason).to eq(:jobfail)
      end
    end
  end
end
