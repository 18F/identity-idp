require 'rails_helper'

RSpec.describe OtpVerificationForm do
  let(:user) { build_stubbed(:user) }
  let(:code) { nil }
  let(:user_otp) { nil }
  let(:user_otp_sent_at) { nil }
  let(:user_otp_expires_at) { 5.minutes.from_now }

  subject(:form) { described_class.new(user, code) }

  before do
    allow(user).to receive(:redis_direct_otp).and_return(user_otp)
    allow(user).to receive(:redis_direct_otp_sent_at).and_return(user_otp_sent_at)
    allow(user).to receive(:redis_direct_otp_expires_at).and_return(user_otp_expires_at)
    allow(user).to receive(:clear_direct_otp)
  end

  describe '#submit' do
    subject(:result) { form.submit }

    context 'when the code is correct' do
      let(:code) { '123456' }
      let(:user_otp) { '123456' }

      it 'returns a successful response' do
        expect(result.to_h).to eq(
          success: true,
          multi_factor_auth_method: 'otp_code',
        )
      end

      it 'clears user pending OTP' do
        expect(user).to receive(:clear_direct_otp)

        result
      end
    end

    context 'when the code is nil' do
      let(:code) { nil }
      let(:user_otp) { '123456' }

      it 'returns a successful response' do
        expect(result.to_h).to eq(
          success: false,
          error_details: {
            code: [:blank],
          },
          multi_factor_auth_method: 'otp_code',
        )
      end

      it 'does not clear user pending OTP' do
        expect(user).not_to receive(:clear_direct_otp)

        result
      end
    end

    context 'when the user does not have a pending OTP' do
      let(:code) { '123456' }
      let(:user_otp) { nil }

      it 'returns an unsuccessful response' do
        expect(result.to_h).to eq(
          success: false,
          error_details: {
            code: [:user_otp_missing],
          },
          multi_factor_auth_method: 'otp_code',
        )
      end

      it 'does not clear user pending OTP' do
        expect(user).not_to receive(:clear_direct_otp)

        result
      end
    end

    context 'when the code is too short' do
      let(:code) { '12345' }
      let(:user_otp) { '123456' }

      it 'returns an unsuccessful response' do
        expect(result.to_h).to eq(
          success: false,
          error_details: {
            code: [:incorrect_length, :incorrect],
          },
          multi_factor_auth_method: 'otp_code',
        )
      end

      it 'does not clear user pending OTP' do
        expect(user).not_to receive(:clear_direct_otp)

        result
      end
    end

    context 'when the code is not numeric' do
      let(:code) { 'l23456' }
      let(:user_otp) { '123456' }

      it 'returns an unsuccessful response' do
        expect(result.to_h).to eq(
          success: false,
          error_details: {
            code: [:pattern_mismatch, :incorrect],
          },
          multi_factor_auth_method: 'otp_code',
        )
      end

      it 'does not clear user pending OTP' do
        expect(user).not_to receive(:clear_direct_otp)

        result
      end
    end

    context 'when the user pending OTP is expired' do
      let(:code) { '123456' }
      let(:user_otp) { '123456' }
      let(:user_otp_expires_at) do
        1.second.ago
      end

      it 'returns an unsuccessful response' do
        expect(result.to_h).to eq(
          success: false,
          error_details: {
            code: [:user_otp_expired],
          },
          multi_factor_auth_method: 'otp_code',
        )
      end

      it 'does not clear user pending OTP' do
        expect(user).not_to receive(:clear_direct_otp)

        result
      end
    end
  end
end
