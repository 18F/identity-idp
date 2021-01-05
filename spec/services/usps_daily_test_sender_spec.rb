require 'rails_helper'

RSpec.describe UspsDailyTestSender do
  subject(:sender) { UspsDailyTestSender.new }

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
    allow(AppConfig.env).to receive(:gpo_designated_receiver_pii).
      and_return(designated_receiver_pii.to_json)
  end

  describe '#run' do
    it 'creates a USPS confirmation and code for the current date' do
      expect { sender.run }.
        to(change { UspsConfirmation.count }.by(1).and(change { UspsConfirmationCode.count }.by(1)))

      usps_confirmation_code = UspsConfirmationCode.find_by(
        otp_fingerprint: Pii::Fingerprinter.fingerprint(sender.otp_from_date),
      )
      expect(usps_confirmation_code).to_not be_nil
      expect(usps_confirmation_code.profile_id).to eq(-1)
    end

    context 'when the designed receiver PII is missing' do
      let(:designated_receiver_pii) { '' }

      it 'does not create usps records' do
        expect { sender.run }.
          to(change { UspsConfirmation.count }.by(0).
            and(change { UspsConfirmationCode.count }.by(0)))
      end

      it 'does not blow up (so the calling job can continue normally) and notifies NewRelic' do
        expect(NewRelic::Agent).to receive(:notice_error)

        expect { sender.run }.to_not raise_error
      end
    end
  end

  describe '#designated_receiver_pii' do
    it 'parses PII from the application config' do
      expect(sender.designated_receiver_pii).to eq(designated_receiver_pii)
    end
  end

  describe '#otp_from_date' do
    it 'formats the date as a 10-digit OTP' do
      expect(sender.otp_from_date(Date.new(2020, 1, 1))).to eq('JAN01_2020')
      expect(sender.otp_from_date(Date.new(2021, 7, 15))).to eq('JUL15_2021')
    end
  end
end
