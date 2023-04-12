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

  describe '#clear_direct_otp' do
    it 'clears otp attributes' do
      user.direct_otp_sent_at = 1.year.ago
      user.direct_otp = '123456'

      user.clear_direct_otp

      expect(user.direct_otp).to be_blank
      expect(user.direct_otp_sent_at).to be_blank
    end
  end
end
