require 'rails_helper'

RSpec.describe AddUserEmailForm do
  subject(:form) { AddUserEmailForm.new }

  let(:original_email) { 'original@example.com' }
  let(:user) { User.create(email: original_email) }

  describe '#submit' do
    let(:new_email) { 'new@example.com' }

    subject(:submit) { form.submit(user, email: new_email) }

    it 'creates a new EmailAddress record for a new email address' do
      expect(EmailAddress.find_with_email(new_email)).to be_nil

      response = submit
      expect(response.success?).to eq(true)

      email_address_record = EmailAddress.find_with_email(new_email)
      expect(email_address_record).to be_present
      expect(email_address_record.confirmed_at).to be_nil
    end

    context 'when the new email address has an expired previous attempt for the same account' do
      before do
        create(
          :email_address,
          email: new_email,
          user: user,
          confirmed_at: nil,
          confirmation_sent_at: 1.month.ago,
        )
      end

      it 'sends a confirmation email, as if it was not previously linked' do
        expect(SendAddEmailConfirmation).to receive(:new).and_call_original

        response = submit
        expect(response.success?).to eq(true)
      end
    end

    context 'when the domain is invalid' do
      let(:new_email) { 'test@çà.com' }

      it 'fails and does not send a confirmation email' do
        expect(SendAddEmailConfirmation).to_not receive(:new)

        response = submit
        expect(response.success?).to eq(false)
      end
    end
  end
end
