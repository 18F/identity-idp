require 'rails_helper'

RSpec.describe UspsDailyTestSender do
  subject(:sender) { UspsDailyTestSender.new }

  let(:email) { Faker::Internet.safe_email }
  let(:designated_receiver_pii) do
    {
      email: email,
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
    it 'creates a USPS confirmation for the current date' do
      expect { sender.run }.
        to(change { UspsConfirmation.count }.by(1).and(change { UspsConfirmationCode.count }.by(1)))

      otp_fingerprint = Pii::Fingerprinter.fingerprint(sender.otp_from_date)
      expect(UspsConfirmationCode.find_by(otp_fingerprint: otp_fingerprint)).to_not be_nil
    end

    context 'when the designed receiver PII is missing' do
      let(:designated_receiver_pii) { '' }

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

  describe '#profile' do
    context 'when no user exists for the email and no profile exists for the user' do
      it 'creates a user and a profile' do
        expect(User.find_with_email(email)).to be_nil

        profile = sender.profile

        user = User.find_with_email(email)
        expect(user.profiles).to eq([profile])
      end
    end

    context 'when a user exists for the email but no profile exists' do
      let!(:existing_user) { create(:user, email: email) }

      it 'creates profile for the user' do
        expect(existing_user.profiles.count).to eq(0)

        profile = sender.profile

        expect(existing_user.reload.profiles).to eq([profile])
      end

      it 'does not create any new users' do
        expect { sender.profile }.to_not(change { User.count })
      end
    end

    context 'when a user for the email exists and has a profile' do
      let!(:existing_user) { create(:user, email: email) }
      let!(:existing_profile) { create(:profile, user: existing_user) }

      it 'loads the existing profile' do
        expect(sender.profile).to eq(existing_profile)
      end
    end
  end
end
