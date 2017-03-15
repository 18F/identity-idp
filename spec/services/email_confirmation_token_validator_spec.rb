require 'rails_helper'

describe EmailConfirmationTokenValidator do
  describe '#submit' do
    context 'confirmation token is invalid' do
      it 'returns FormResponse with success: false' do
        user = build_stubbed(:user, :unconfirmed)
        user.errors.add(:confirmation_token, t('errors.messages.invalid'))

        response = instance_double(FormResponse)
        allow(FormResponse).to receive(:new).and_return(response)

        errors = { confirmation_token: [t('errors.messages.invalid')] }
        extra = {
          user_id: user.uuid,
          existing_user: false,
        }

        validator = EmailConfirmationTokenValidator.new(user).submit

        expect(validator).to eq response
        expect(FormResponse).to have_received(:new).
          with(success: false, errors: errors, extra: extra)
      end
    end

    context 'confirmation token has expired' do
      it 'returns FormResponse with success: false' do
        user = build_stubbed(:user, :unconfirmed)
        allow(user).to receive(:confirmation_period_expired?).and_return(true)

        response = instance_double(FormResponse)
        allow(FormResponse).to receive(:new).and_return(response)

        errors = { confirmation_token: [t('errors.messages.expired')] }
        extra = {
          user_id: user.uuid,
          existing_user: false,
        }

        validator = EmailConfirmationTokenValidator.new(user).submit

        expect(validator).to eq response
        expect(FormResponse).to have_received(:new).
          with(success: false, errors: errors, extra: extra)
      end
    end

    context 'confirmation token has already been used' do
      it 'returns FormResponse with success: false' do
        user = build_stubbed(:user)
        user.errors.add(:email, :already_confirmed)

        response = instance_double(FormResponse)
        allow(FormResponse).to receive(:new).and_return(response)

        errors = { email: [t('errors.messages.already_confirmed')] }
        extra = {
          user_id: user.uuid,
          existing_user: true,
        }

        validator = EmailConfirmationTokenValidator.new(user).submit

        expect(validator).to eq response
        expect(FormResponse).to have_received(:new).
          with(success: false, errors: errors, extra: extra)
      end
    end

    context 'confirmation token is valid' do
      it 'returns FormResponse with success: true' do
        user = build_stubbed(:user, :unconfirmed)

        response = instance_double(FormResponse)
        allow(FormResponse).to receive(:new).and_return(response)

        extra = {
          user_id: user.uuid,
          existing_user: false,
        }

        validator = EmailConfirmationTokenValidator.new(user).submit

        expect(validator).to eq response
        expect(FormResponse).to have_received(:new).
          with(success: true, errors: {}, extra: extra)
      end
    end
  end
end
