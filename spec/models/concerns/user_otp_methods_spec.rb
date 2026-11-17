require 'rails_helper'

RSpec.describe UserOtpMethods do
  let(:user_class) do
    Class.new do
      include UserOtpMethods

      attr_accessor :direct_otp, :direct_otp_sent_at, :direct_otp_phone_fingerprint

      # minimal ActiveRecord impl
      def update(attrs)
        attrs.each do |key, value|
          send(:"#{key}=", value)
        end
      end
    end
  end

  let(:user) do
    user_class.new
  end

  describe '#create_direct_otp' do
    it 'issues a code and records the phone it was sent to as a fingerprint' do
      user.create_direct_otp('+1 (202) 555-1212')

      expect(user.direct_otp).to match(/\A\d{6}\z/)
      expect(user.direct_otp_sent_at).to be_within(1.second).of(Time.zone.now)
      expect(user.direct_otp_phone_fingerprint).to eq(
        Pii::Fingerprinter.fingerprint('+1 202-555-1212'),
      )
    end
  end

  describe '#direct_otp_sent_to?' do
    before { user.create_direct_otp('+1 (202) 555-1212') }

    it 'is true for the phone the code was sent to, however it is formatted' do
      expect(user.direct_otp_sent_to?('+12025551212')).to eq(true)
      expect(user.direct_otp_sent_to?('(202) 555-1212')).to eq(true)
    end

    it 'is false for another phone' do
      expect(user.direct_otp_sent_to?('+1 (202) 555-1213')).to eq(false)
    end

    it 'is false when no code is pending' do
      user.clear_direct_otp

      expect(user.direct_otp_sent_to?('+1 (202) 555-1212')).to eq(false)
    end
  end

  describe '#clear_direct_otp' do
    it 'clears otp attributes' do
      user.direct_otp_sent_at = 1.year.ago
      user.direct_otp = '123456'
      user.direct_otp_phone_fingerprint = 'abc'

      user.clear_direct_otp

      expect(user.direct_otp).to be_blank
      expect(user.direct_otp_sent_at).to be_blank
      expect(user.direct_otp_phone_fingerprint).to be_blank
    end
  end
end
