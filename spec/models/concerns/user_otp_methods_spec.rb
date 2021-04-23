require 'rails_helper'

RSpec.describe UserOtpMethods do
  let(:user_class) do
    Class.new do
      include UserOtpMethods

      attr_accessor :direct_otp, :direct_otp_sent_at

      # minimal ActiveRecord impl
      def update(attrs)
        attrs.each do |key, value|
          send("#{key}=", value)
        end
      end
    end
  end

  let(:user) do
    user_class.new
  end

  describe '#authenticate_direct_otp' do
    it 'is false when the OTP has expired' do
      user.direct_otp_sent_at = 1.year.ago
      user.direct_otp = '123456'

      expect(user.authenticate_direct_otp('123456')).to eq(false)
    end

    it 'is true when the code is the same code' do
      user.create_direct_otp
      expect(user.direct_otp).to be_present

      expect(user.authenticate_direct_otp(user.direct_otp)).to eq(true)
    end

    it 'crockford base-32 normalizes incoming codes' do
      user.direct_otp_sent_at = 5.seconds.ago
      user.direct_otp = '000111' # canonical encoding

      expect(user.authenticate_direct_otp('000i1L')).to eq(true)
    end

    it 'rejects similar crockford encodings but the wrong length' do
      user.direct_otp_sent_at = 5.seconds.ago
      user.direct_otp = '000111' # canonical encoding

      expect(user.authenticate_direct_otp('0i1L')).to eq(false)
    end
  end
end
