require 'rails_helper'

describe TwoFactorOptionsForm do
  let(:user) { build(:user) }
  subject { described_class.new(user) }

  describe '#submit' do
    it 'is successful if the selection is valid' do
      %w[voice sms auth_app piv_cac].each do |selection|
        result = subject.submit(selection: selection)

        expect(result.success?).to eq true
      end
    end

    it 'is unsuccessful if the selection is invalid' do
      result = subject.submit(selection: '!!!!')

      expect(result.success?).to eq false
      expect(result.errors).to include :selection
    end

    context "when the selection is different from the user's otp_delivery_preference" do
      it "updates the user's otp_delivery_preference" do
        user_updater = instance_double(UpdateUser)
        allow(UpdateUser).
          to receive(:new).
          with(
            user: user,
            attributes: { otp_delivery_preference: 'voice' },
          ).
          and_return(user_updater)
        expect(user_updater).to receive(:call)

        subject.submit(selection: 'voice')
      end
    end

    context "when the selection is the same as the user's otp_delivery_preference" do
      it "does not update the user's otp_delivery_preference" do
        expect(UpdateUser).to_not receive(:new)

        subject.submit(selection: 'sms')
      end
    end

    context 'when the selection is not voice or sms' do
      it "does not update the user's otp_delivery_preference" do
        expect(UpdateUser).to_not receive(:new)

        subject.submit(selection: 'auth_app')
      end
    end
  end
end
