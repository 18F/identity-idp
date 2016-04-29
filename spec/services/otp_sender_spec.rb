require 'rails_helper'

describe UserOtpSender do
  describe '#send_otp' do
    context 'when user only has email 2FA and is not two_factor_enabled' do
      it 'resets unconfirmed_mobile and only sends OTP to email' do
        user = create(:user, unconfirmed_mobile: '5005550006')
        allow(user.second_factors).to receive(:pluck).with(:name).and_return(['Email'])

        expect(EmailSecondFactor).to receive(:transmit).with(user)

        UserOtpSender.new(user).send_otp

        expect(user.unconfirmed_mobile).to be_nil
      end
    end

    context 'when user is two_factor_enabled and does not have unconfirmed_mobile' do
      it 'sends OTP to all 2FA types' do
        user = build_stubbed(:user)
        email = build_stubbed(:second_factor, :email)
        mobile = build_stubbed(:second_factor, :mobile)

        allow(user).to receive(:second_factors).and_return([email, mobile])
        allow(user.second_factors).to receive(:pluck).with(:name).and_return(%w(Email Mobile))
        allow(user).to receive(:two_factor_enabled?).and_return(true)

        expect(EmailSecondFactor).to receive(:transmit).with(user)
        expect(MobileSecondFactor).to receive(:transmit).with(user)

        UserOtpSender.new(user).send_otp
      end
    end

    context 'when user is two_factor_enabled and has an unconfirmed_mobile' do
      it 'generates a new OTP and only sends OTP to unconfirmed_mobile' do
        user = build_stubbed(
          :user, unconfirmed_mobile: '5005550006', otp_secret_key: 'lzmh6ekrnc5i6aaq')

        email = build_stubbed(:second_factor, :email)
        mobile = build_stubbed(:second_factor, :mobile)

        allow(user).to receive(:second_factors).and_return([email, mobile])
        allow(user.second_factors).to receive(:pluck).with(:name).and_return(%w(Email Mobile))
        allow(user).to receive(:two_factor_enabled?).and_return(true)

        expect(EmailSecondFactor).to_not receive(:transmit).with(user)
        expect(MobileSecondFactor).to receive(:transmit).with(user)

        UserOtpSender.new(user).send_otp

        expect(user.otp_secret_key).to_not eq 'lzmh6ekrnc5i6aaq'
      end
    end
  end

  describe '#otp_should_only_go_to_mobile?' do
    context 'when the user has an unconfirmed_mobile and is two_factor_enabled' do
      it 'returns true' do
        user = build_stubbed(:user, unconfirmed_mobile: '5005550006')
        allow(user).to receive(:two_factor_enabled?).and_return(true)

        expect(UserOtpSender.new(user).otp_should_only_go_to_mobile?).to eq true
      end
    end

    context 'when the user has an unconfirmed_mobile and is not two_factor_enabled' do
      it 'returns false' do
        user = build_stubbed(:user, unconfirmed_mobile: '5005550006')
        allow(user).to receive(:two_factor_enabled?).and_return(false)

        expect(UserOtpSender.new(user).otp_should_only_go_to_mobile?).to eq false
      end
    end

    context 'when the user does not have an unconfirmed_mobile and is not two_factor_enabled' do
      it 'returns false' do
        user = build_stubbed(:user)
        allow(user).to receive(:two_factor_enabled?).and_return(false)

        expect(UserOtpSender.new(user).otp_should_only_go_to_mobile?).to eq false
      end
    end

    context 'when the user does not have an unconfirmed_mobile and is two_factor_enabled' do
      it 'returns false' do
        user = build_stubbed(:user)
        allow(user).to receive(:two_factor_enabled?).and_return(true)

        expect(UserOtpSender.new(user).otp_should_only_go_to_mobile?).to eq false
      end
    end
  end

  describe '#reset_otp_state' do
    context 'when the user has a confirmed mobile and unconfirmed_mobile' do
      it 'sets unconfirmed_mobile to nil and keeps mobile 2FA' do
        user = create(:user, :with_mobile, unconfirmed_mobile: '5005550006')

        UserOtpSender.new(user).reset_otp_state

        expect(user.unconfirmed_mobile).to be_nil
        expect(user.second_factors.pluck(:name).sort).to eq %w(Mobile)
      end
    end

    context 'when the user has an unconfirmed_mobile but no mobile' do
      it 'sets unconfirmed_mobile to nil and keeps mobile 2FA' do
        user = create(:user, :both_tfa_confirmed, unconfirmed_mobile: '5005550006')

        UserOtpSender.new(user).reset_otp_state

        expect(user.unconfirmed_mobile).to be_nil
        expect(user.second_factors.pluck(:name).sort).to eq %w(Email)
      end
    end
  end
end
