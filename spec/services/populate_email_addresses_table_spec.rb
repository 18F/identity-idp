require 'rails_helper'

describe PopulateEmailAddressesTable do
  let(:subject) { described_class.new }

  describe '#call' do
    context 'a user with no email' do
      let!(:user) { create(:user, email: '', confirmed_at: nil) }

      it 'migrates nothing' do
        expect(user.email_addresses).to be_empty

        expect { subject.call }.to change { EmailAddress.count }.by(0)
      end
    end

    context 'a user with an email' do
      let!(:user) { create(:user) }

      context 'and no email_address entry' do
        before(:each) do
          user.email_addresses.clear
          user.reload
        end

        it 'migrates without decrypting and re-encrypting' do
          expect(EncryptedAttribute).to_not receive(:new)
          subject.call
        end

        it 'migrates the email' do
          expect { subject.call }.to change { EmailAddress.count }.by(1)

          address = user.reload.email_addresses.first
          expect(user.email).to eq address.email
          expect(user.confirmed_at).to eq user.confirmed_at
          expect(user.confirmation_sent_at).to eq user.confirmation_sent_at
          expect(user.confirmation_token).to eq user.confirmation_token
        end
      end

      context 'and an existing email_address entry' do
        it 'adds no new rows' do
          expect { subject.call }.to change { EmailAddress.count }.by(0)
        end
      end
    end
  end
end
