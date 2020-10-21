require 'rails_helper'

describe Idv::PhoneStep do
  include IdvHelper

  let(:user) { build(:user) }
  let(:service_provider) do
    create(:service_provider,
           issuer: 'http://sp.example.com',
           app_id: '123')
  end
  let(:idv_session) do
    idvs = Idv::Session.new(user_session: {},
                            current_user: user,
                            issuer: service_provider.issuer)
    idvs.applicant = { first_name: 'Some' }
    idvs
  end
  let(:good_phone) { '2255555000' }
  let(:bad_phone) do
    IdentityIdpFunctions::AddressMockClient::UNVERIFIABLE_PHONE_NUMBER
  end
  let(:fail_phone) do
    IdentityIdpFunctions::AddressMockClient::FAILED_TO_CONTACT_PHONE_NUMBER
  end
  let(:timeout_phone) do
    IdentityIdpFunctions::AddressMockClient::PROOFER_TIMEOUT_PHONE_NUMBER
  end

  subject { described_class.new(idv_session: idv_session) }

  describe '#submit' do
    it 'succeeds with good params' do
      context = { stages: [{ address: 'AddressMock' }] }
      extra = { vendor: { messages: [], context: context, exception: nil, timed_out: false } }

      subject.submit(phone: good_phone)

      expect(subject.async_state.status).to eq :done
      result = subject.async_state_done(subject.async_state)
      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(true)
      expect(result.errors).to be_empty
      expect(result.extra).to eq(extra)
      expect(idv_session.vendor_phone_confirmation).to eq true
      expect(idv_session.applicant).to eq(first_name: 'Some',
                                          phone: good_phone,
                                          uuid_prefix: service_provider.app_id)
    end

    it 'fails with bad params' do
      context = { stages: [{ address: 'AddressMock' }] }
      extra = { vendor: { messages: [], context: context, exception: nil, timed_out: false } }

      subject.submit(phone: bad_phone)
      expect(subject.async_state.status).to eq :done
      result = subject.async_state_done(subject.async_state)

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
      expect(result.errors).to eq(phone: ['The phone number could not be verified.'])
      expect(result.extra).to eq(extra)
      expect(idv_session.vendor_phone_confirmation).to be_falsy
      expect(idv_session.user_phone_confirmation).to be_falsy
      expect(idv_session.applicant).to eq(first_name: 'Some')
    end

    it 'increments step attempts' do
      original_step_attempts = idv_session.step_attempts[:phone]

      subject.submit(phone: bad_phone)
      expect(subject.async_state.status).to eq :done
      _result = subject.async_state_done(subject.async_state)

      expect(idv_session.step_attempts[:phone]).to eq(original_step_attempts + 1)
    end

    it 'does not increment step attempts when the vendor request times out' do
      original_step_attempts = idv_session.step_attempts[:phone]

      subject.submit(phone: timeout_phone)

      expect(idv_session.step_attempts[:phone]).to eq(original_step_attempts)
    end

    it 'does not increment step attempts when the vendor raises an exception' do
      original_step_attempts = idv_session.step_attempts[:phone]

      subject.submit(phone: fail_phone)

      expect(idv_session.step_attempts[:phone]).to eq(original_step_attempts)
    end

    it 'marks the phone as confirmed if it matches 2FA phone' do
      user.phone_configurations = [build(:phone_configuration, user: user, phone: good_phone)]

      subject.submit(phone: good_phone)
      expect(subject.async_state.status).to eq :done
      result = subject.async_state_done(subject.async_state)

      expect(result.success?).to eq(true)
      expect(idv_session.vendor_phone_confirmation).to eq(true)
      expect(idv_session.user_phone_confirmation).to eq(true)
    end

    it 'does not mark the phone as confirmed if it does not match 2FA phone' do
      subject.submit(phone: good_phone)
      expect(subject.async_state.status).to eq :done
      result = subject.async_state_done(subject.async_state)

      expect(result.success?).to eq(true)
      expect(idv_session.vendor_phone_confirmation).to eq(true)
      expect(idv_session.user_phone_confirmation).to be_falsy
    end
  end

  describe '#failure_reason' do
    context 'when there are idv attempts remaining' do
      it 'returns :warning' do
        subject.submit(phone: bad_phone)
        expect(subject.async_state.status).to eq :done
        _result = subject.async_state_done(subject.async_state)

        expect(subject.failure_reason).to eq(:warning)
      end
    end

    context 'when there are not idv attempts remaining' do
      it 'returns :fail' do
        idv_session.step_attempts[:phone] = idv_max_attempts - 1

        subject.submit(phone: bad_phone)
        expect(subject.async_state.status).to eq :done
        _result = subject.async_state_done(subject.async_state)

        expect(subject.failure_reason).to eq(:fail)
      end
    end

    context 'when the vendor raises a timeout exception' do
      it 'returns :timeout' do
        subject.submit(phone: timeout_phone)
        expect(subject.async_state.status).to eq :done
        _result = subject.async_state_done(subject.async_state)

        expect(subject.failure_reason).to eq(:timeout)
      end
    end

    context 'when the vendor raises an exception' do
      it 'returns :jobfail' do
        subject.submit(phone: fail_phone)
        expect(subject.async_state.status).to eq :done
        _result = subject.async_state_done(subject.async_state)

        expect(subject.failure_reason).to eq(:jobfail)
      end
    end
  end
end
