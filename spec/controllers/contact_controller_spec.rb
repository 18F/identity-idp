require 'rails_helper'

include Features::MailerHelper

describe ContactController do
  describe '#create' do
    it 'sends email and lets user know submission was success' do
      post :create, contact_form: { email_or_tel: 'foo' }

      expect(response).to redirect_to contact_url
      expect(flash[:success]).to eq t('contact.messages.thanks')

      expect(response).to render_template('user_mailer/contact_request')
      expect(last_email.subject).to eq t('mailer.contact_request.subject')
    end

    it 'does not send email and renders new if form invalid' do
      post :create, contact_form: { email_or_tel: '' }

      expect(response).to_not render_template('user_mailer/contact_request')
      expect(response).to render_template(:new)
    end
  end
end
