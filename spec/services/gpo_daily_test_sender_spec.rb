require 'rails_helper'

RSpec.describe GpoDailyTestSender do
  subject(:sender) { GpoDailyTestSender.new }

  let(:designated_receiver_pii) do
    {
      first_name: 'Emmy',
      last_name: 'Examperson',
      address1: '123 Main St',
      city: 'Washington',
      state: 'DC',
      zipcode: '20001',
    }
  end

  before do
    allow(IdentityConfig.store).to receive(:gpo_designated_receiver_pii).
      and_return(designated_receiver_pii)
  end

  describe '#run' do
    it 'creates a GPO confirmation and code for the current date' do
      expect { sender.run }.
        to(change { GpoConfirmation.count }.by(1).and(change { GpoConfirmationCode.count }.by(1)))

      gpo_confirmation_code = GpoConfirmationCode.find_by(
        otp_fingerprint: Pii::Fingerprinter.fingerprint(sender.otp_from_date),
      )
      expect(gpo_confirmation_code).to_not be_nil
      expect(gpo_confirmation_code.profile_id).to eq(-1)
    end

    context 'when attempting handle the designated reciver renders an error' do
      let(:designated_receiver_pii) { {} }

      it 'does not create gpo records' do
        expect { sender.run }.
          to(change { GpoConfirmation.count }.by(0).
            and(change { GpoConfirmationCode.count }.by(0)))
      end

      it 'warns and does not blow up (so the calling job can continue normally)' do
        expect(Rails.logger).to receive(:warn) do |msg|
          payload = JSON.parse(msg, symbolize_names: true)
          expect(payload[:message]).to eq(
            'missing valid designated receiver pii, not enqueueing a test sender',
          )
        end

        expect { sender.run }.to_not raise_error
      end
    end
  end

  describe '#otp_from_date' do
    it 'formats the date as a 10-digit OTP' do
      expect(sender.otp_from_date(Date.new(2020, 1, 1))).to eq('JAN01_2020')
      expect(sender.otp_from_date(Date.new(2021, 7, 15))).to eq('JUL15_2021')
    end
  end
end
