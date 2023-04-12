require 'rails_helper'

RSpec.describe Users::EmailsController do
  describe '#verify' do
    context 'with malformed payload' do
      it 'does not blow up' do
        expect { get :verify, params: { request_id: { foo: 'bar' } } }.
          to_not raise_error
      end
    end
  end

  describe '#limit' do
    context 'user exceeds email limit' do
      let(:user) { create(:user) }
      before do
        stub_sign_in(user)

        while EmailPolicy.new(user).can_add_email?
          email = Faker::Internet.safe_email
          user.email_addresses.create(email: email, confirmed_at: Time.zone.now)
        end
      end
      it 'displays error if email exceeds limit' do
        controller.request.headers.merge({ HTTP_REFERER: account_url })

        get :show
        expect(response).to redirect_to(account_url(anchor: 'emails'))
        expect(response.request.flash[:email_error]).to_not be_nil
      end
    end
  end

  describe '#resend' do
    let(:user) { create(:user) }
    before do
      stub_sign_in(user)
      stub_analytics
      allow(@analytics).to receive(:track_event)
    end

    context 'valid email exists in session' do
      it 'sends email' do
        email = Faker::Internet.safe_email

        expect(@analytics).to receive(:track_event).with(
          'Add Email Requested',
          { success: true, errors: {}, user_id: user.uuid, domain_name: email.split('@').last },
        )

        expect(@analytics).to receive(:track_event).with(
          'Resend Add Email Requested',
          { success: true },
        )

        post :add, params: { user: { email: email } }
        expect(last_email_sent).to have_subject(
          t('user_mailer.email_confirmation_instructions.subject'),
        )

        post :resend
        expect(response).to redirect_to(add_email_verify_email_url)
        expect(last_email_sent).to have_subject(
          t('user_mailer.email_confirmation_instructions.subject'),
        )
        expect(ActionMailer::Base.deliveries.count).to eq 2
      end
    end

    context 'no valid email exists in session' do
      it 'shows an error and redirects to add email page' do
        expect(@analytics).to receive(:track_event).with(
          'Resend Add Email Requested',
          { success: false },
        )

        post :resend
        expect(flash[:error]).to eq t('errors.general')
        expect(response).to redirect_to(add_email_url)
        expect(ActionMailer::Base.deliveries.count).to eq 0
      end
    end
  end
end
