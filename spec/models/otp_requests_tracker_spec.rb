require 'rails_helper'

describe OtpRequestsTracker do
  let(:phone) { '+1 703 555 1212' }
  let(:phone_fingerprint) { Pii::Fingerprinter.fingerprint(phone) }

  describe '.find_or_create_with_phone_and_confirmed' do
    context 'match found' do
      it 'returns the existing record and does not change it' do
        OtpRequestsTracker.create(
          phone_fingerprint: phone_fingerprint,
          phone_confirmed: true,
          otp_send_count: 3,
          otp_last_sent_at: Time.zone.now - 1.hour,
        )

        existing = OtpRequestsTracker.where(phone_fingerprint: phone_fingerprint).first

        expect { OtpRequestsTracker.find_or_create_with_phone_and_confirmed(phone, true) }.
          to_not change(OtpRequestsTracker, :count)
        expect { OtpRequestsTracker.find_or_create_with_phone_and_confirmed(phone, true) }.
          to_not change(existing, :otp_send_count)
        expect { OtpRequestsTracker.find_or_create_with_phone_and_confirmed(phone, true) }.
          to_not change(existing, :otp_last_sent_at)
      end
    end

    context 'match not found' do
      it 'creates new record with otp_send_count = 0' do
        expect { OtpRequestsTracker.find_or_create_with_phone_and_confirmed(phone, true) }.
          to change(OtpRequestsTracker, :count).by(1)

        existing = OtpRequestsTracker.where(phone_fingerprint: phone_fingerprint).first

        expect(existing.otp_send_count).to eq 0
      end
    end
  end

  describe '.atomic_increment' do
    it 'updates otp_last_sent_at' do
      old_ort = OtpRequestsTracker.create(
        phone_fingerprint: phone_fingerprint,
        otp_send_count: 3,
        phone_confirmed: true,
        otp_last_sent_at: Time.zone.now - 1.hour,
      )
      new_ort = OtpRequestsTracker.atomic_increment(old_ort.id)
      expect(new_ort.otp_last_sent_at).to be > old_ort.otp_last_sent_at
    end

    it 'increments the otp_send_count' do
      old_ort = OtpRequestsTracker.create(
        phone_fingerprint: phone_fingerprint,
        otp_send_count: 3,
        phone_confirmed: true,
        otp_last_sent_at: Time.zone.now,
      )
      new_ort = OtpRequestsTracker.atomic_increment(old_ort.id)
      expect(new_ort.otp_send_count - 1).to eq(old_ort.otp_send_count)
    end
  end
end
