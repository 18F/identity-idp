require 'rails_helper'

describe Idv::PhoneStep do
  include IdvHelper

  let(:user) { create(:user) }
  let(:service_provider) do
    create(
      :service_provider,
      issuer: 'http://sp.example.com',
      app_id: '123',
    )
  end
  let(:idv_session) do
    idvs = Idv::Session.new(
      user_session: {},
      current_user: user,
      service_provider: service_provider,
    )
    idvs.applicant = {
      first_name: 'Some',
      last_name: 'One',
      uuid: SecureRandom.uuid,
      dob: 50.years.ago.to_date.to_s,
      ssn: '666-12-1234',
    }
    idvs
  end
  let(:good_phone) { '2255555000' }
  let(:bad_phone) do
    Proofing::Mock::AddressMockClient::UNVERIFIABLE_PHONE_NUMBER
  end
  let(:fail_phone) do
    Proofing::Mock::AddressMockClient::FAILED_TO_CONTACT_PHONE_NUMBER
  end
  let(:timeout_phone) do
    Proofing::Mock::AddressMockClient::PROOFER_TIMEOUT_PHONE_NUMBER
  end
  let(:trace_id) { SecureRandom.uuid }

  subject do
    described_class.new(
      idv_session: idv_session,
      trace_id: trace_id,
    )
  end

  describe '#submit' do
    let(:throttle) { Throttle.new(throttle_type: :proof_address, user: user) }

    it 'succeeds with good params' do
      proofing_phone = Phonelib.parse(good_phone)
      extra = {
        phone_fingerprint: Pii::Fingerprinter.fingerprint(proofing_phone.e164),
        country_code: proofing_phone.country,
        area_code: proofing_phone.area_code,
        vendor: {
          vendor_name: 'AddressMock',
          exception: nil,
          timed_out: false,
          transaction_id: 'address-mock-transaction-id-123',
          reference: '',
        },
      }

      original_applicant = idv_session.applicant.dup

      subject.submit(phone: good_phone)

      expect(subject.async_state).to be_done
      result = subject.async_state_done(subject.async_state)
      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(true)
      expect(result.errors).to be_empty
      expect(result.extra).to eq(extra)
      expect(idv_session.vendor_phone_confirmation).to eq true
      expect(idv_session.applicant).to eq(
        original_applicant.merge(
          phone: good_phone,
          uuid_prefix: service_provider.app_id,
        ),
      )
    end

    it 'fails with bad params' do
      proofing_phone = Phonelib.parse(bad_phone)
      extra = {
        phone_fingerprint: Pii::Fingerprinter.fingerprint(proofing_phone.e164),
        country_code: proofing_phone.country,
        area_code: proofing_phone.area_code,
        vendor: {
          vendor_name: 'AddressMock',
          exception: nil,
          timed_out: false,
          transaction_id: 'address-mock-transaction-id-123',
          reference: '',
        },
      }

      original_applicant = idv_session.applicant.dup

      subject.submit(phone: bad_phone)
      expect(subject.async_state.done?).to eq true
      result = subject.async_state_done(subject.async_state)

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
      expect(result.errors).to eq(phone: ['The phone number could not be verified.'])
      expect(result.extra).to eq(extra)
      expect(idv_session.vendor_phone_confirmation).to be_falsy
      expect(idv_session.user_phone_confirmation).to be_falsy
      expect(idv_session.applicant).to eq(original_applicant)
    end

    it 'increments step attempts' do
      expect do
        subject.submit(phone: bad_phone)
        expect(subject.async_state.done?).to eq true
        _result = subject.async_state_done(subject.async_state)
      end.to(change { throttle.fetch_state!.attempts }.by(1))
    end

    it 'does not increment step attempts when the vendor request times out' do
      expect { subject.submit(phone: timeout_phone) }.to_not change { throttle.attempts }
    end

    it 'does not increment step attempts when the vendor raises an exception' do
      expect { subject.submit(phone: fail_phone) }.to_not change { throttle.attempts }
    end

    it 'marks the phone as unconfirmed if it matches 2FA phone' do
      user.phone_configurations = [build(:phone_configuration, user: user, phone: good_phone)]

      subject.submit(phone: good_phone)
      expect(subject.async_state.done?).to eq true
      result = subject.async_state_done(subject.async_state)

      expect(result.success?).to eq(true)
      expect(idv_session.vendor_phone_confirmation).to eq(true)
      expect(idv_session.user_phone_confirmation).to eq(false)
    end

    it 'does not mark the phone as confirmed if it does not match 2FA phone' do
      subject.submit(phone: good_phone)
      expect(subject.async_state.done?).to eq true
      result = subject.async_state_done(subject.async_state)

      expect(result.success?).to eq(true)
      expect(idv_session.vendor_phone_confirmation).to eq(true)
      expect(idv_session.user_phone_confirmation).to be_falsy
    end

    it 'records the transaction_id in the cost' do
      expect do
        subject.submit(phone: good_phone)
        subject.async_state_done(subject.async_state)
      end.to(change { SpCost.count }.by(1))

      sp_cost = SpCost.last
      expect(sp_cost.issuer).to eq(service_provider.issuer)
      expect(sp_cost.transaction_id).to eq('address-mock-transaction-id-123')
    end

    it 'records the transaction_id in the cost for failures too' do
      expect do
        subject.submit(phone: bad_phone)
        subject.async_state_done(subject.async_state)
      end.to(change { SpCost.count }.by(1))

      sp_cost = SpCost.last
      expect(sp_cost.issuer).to eq(service_provider.issuer)
      expect(sp_cost.transaction_id).to eq('address-mock-transaction-id-123')
    end
  end

  describe '#failure_reason' do
    context 'when there are idv attempts remaining' do
      it 'returns :warning' do
        subject.submit(phone: bad_phone)
        expect(subject.async_state.done?).to eq true
        _result = subject.async_state_done(subject.async_state)

        expect(subject.failure_reason).to eq(:warning)
      end
    end

    context 'when there are not idv attempts remaining' do
      it 'returns :fail' do
        Throttle.new(throttle_type: :proof_address, user: user).increment_to_throttled!

        subject.submit(phone: bad_phone)
        expect(subject.async_state.done?).to eq true
        _result = subject.async_state_done(subject.async_state)

        expect(subject.failure_reason).to eq(:fail)
      end
    end

    context 'when the vendor raises a timeout exception' do
      it 'returns :timeout' do
        subject.submit(phone: timeout_phone)
        expect(subject.async_state.done?).to eq true
        _result = subject.async_state_done(subject.async_state)

        expect(subject.failure_reason).to eq(:timeout)
      end
    end

    context 'when the vendor raises an exception' do
      it 'returns :jobfail' do
        subject.submit(phone: fail_phone)
        expect(subject.async_state.done?).to eq true
        _result = subject.async_state_done(subject.async_state)

        expect(subject.failure_reason).to eq(:jobfail)
      end
    end
  end
end
