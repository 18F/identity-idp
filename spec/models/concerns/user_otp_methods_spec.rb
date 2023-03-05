require 'rails_helper'

RSpec.describe UserOtpMethods do
  let(:user_class) do
    Class.new do
      include UserOtpMethods

      attr_accessor :direct_otp, :direct_otp_sent_at

      def id
        1
      end

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
      user.create_direct_otp
      expect(user.redis_direct_otp).to_not be_blank
      expect(user.redis_direct_otp_sent_at).to_not be_blank

      user.clear_direct_otp

      expect(user.redis_direct_otp).to be_blank
      expect(user.redis_direct_otp_sent_at).to be_blank
    end
  end
end
