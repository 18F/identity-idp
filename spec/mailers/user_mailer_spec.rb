require 'rails_helper'

describe UserMailer, type: :mailer do
  let(:user) { build_stubbed(:user) }

  describe 'email_changed' do
    let(:mail) { UserMailer.email_changed('old@email.com') }

    it 'sends to the old email' do
      expect(mail.to).to eq ['old@email.com']
    end

    it 'renders the subject' do
      expect(mail.subject).to eq('Email change notification')
    end

    it 'renders the body' do
      expect(mail.body).
        to have_content(
          'You have asked Upaya to change the email address currently associated with your ' \
          'Upaya Account')
    end
  end

  describe 'password_changed' do
    let(:mail) { UserMailer.password_changed(user) }

    it 'sends to the current email' do
      expect(mail.to).to eq [user.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('devise.mailer.password_updated.subject')
    end

    it 'renders the body' do
      expect(mail.body).
        to have_content(
          'You have asked Upaya to change the password currently associated with your ' \
          'Upaya Account')
    end
  end

  describe 'password_expiry' do
    let(:mail) { UserMailer.password_expiry(user) }

    it 'sends to the current email' do
      expect(mail.to).to eq [user.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('upaya.mailer.password_expires_soon.subject')
    end

    it 'renders the body' do
      expect(mail.body).to have_content('Your Upaya Account password will expire in 15 days')
    end
  end

  describe 'signup_with_your_email' do
    let(:mail) { UserMailer.signup_with_your_email(user.email) }

    it 'sends to the current email' do
      expect(mail.to).to eq [user.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq 'Email Confirmation Notification'
    end

    it 'renders the body' do
      expect(mail.body).to have_content('This email address is already in use.')
    end
  end
end
