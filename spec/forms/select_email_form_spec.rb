require 'rails_helper'

RSpec.describe SelectEmailForm do
  let(:user) { create(:user, :fully_registered, :with_multiple_emails) }
  describe '#submit' do
    it 'returns the email successfully' do
      form = SelectEmailForm.new(user)
      response = form.submit(selection: user.email_addresses.last.id)

      expect(response.success?).to eq(true)
    end

    it 'returns an error when submitting an invalid email' do
      form = SelectEmailForm.new(user)
      response = form.submit(selection: nil)

      expect(response.success?).to eq(false)
    end

    context 'with an unconfirmed email address added' do
      before do
        create(
          :email_address,
          email: 'michael.business@business.com',
          user: user,
          confirmed_at: nil,
          confirmation_sent_at: 1.month.ago,
        )
      end

      it 'returns an error' do
        form = SelectEmailForm.new(user)
        response = form.submit(selection: user.email_addresses.last.id)

        expect(response.success?).to eq(false)
      end
    end

    context 'with another user\'s email' do
      let(:user2) { create(:user, :fully_registered, :with_multiple_emails) }
      before do
        create(
          :email_address,
          email: 'michael.business@business.com',
          user: user2,
          confirmed_at: nil,
          confirmation_sent_at: 1.month.ago,
        )
        @email2 = user2.email_addresses.last.id
      end

      it 'returns an error' do
        form = SelectEmailForm.new(user)
        response = form.submit(selection: @email2)

        expect(response.success?).to eq(false)
      end
    end
  end
end
