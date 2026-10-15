require 'rails_helper'

RSpec.describe AccountRecovery::PendingController do
  let(:user) { create(:user, :fully_registered) }

  describe '#resend' do
    before do
      allow(IdentityConfig.store).to receive(:deliver_mail_async).and_return(false)
    end

    it 'requires password authentication' do
      expect { post :resend }.not_to change { ActionMailer::Base.deliveries.size }
      expect(response).to redirect_to(root_url)
    end

    context 'when signed in before 2FA' do
      before { stub_sign_in_before_2fa(user) }

      it 'does not send an email without an active request' do
        expect { post :resend }.not_to change { ActionMailer::Base.deliveries.size }
        expect(response).to render_template('pages/page_not_found')
      end

      it 'does not use another user’s request' do
        create(:account_recovery_request, :waiting)

        expect { post :resend }.not_to change { ActionMailer::Base.deliveries.size }
        expect(response).to render_template('pages/page_not_found')
      end

      it 'does not resend the initial notification after a request is granted' do
        create(:account_recovery_request, :granted, user: user)

        expect { post :resend }.not_to change { ActionMailer::Base.deliveries.size }
        expect(response).to render_template('pages/page_not_found')
      end

      context 'with a waiting request' do
        let!(:recovery_request) { create(:account_recovery_request, :waiting, user: user) }
        let!(:signed_in_email) do
          create(:email_address, user: user, last_sign_in_at: Time.zone.now)
        end

        it 'resends only to the sign-in email without changing the request or waiting period' do
          original_attributes = recovery_request.attributes
          request_count = AccountRecoveryRequest.count

          expect { post :resend }.to change { ActionMailer::Base.deliveries.size }.by(1)

          expect(ActionMailer::Base.deliveries.last.to).to eq([signed_in_email.email])
          expect(recovery_request.reload.attributes).to eq(original_attributes)
          expect(AccountRecoveryRequest.count).to eq(request_count)
          expect(flash[:success]).to eq(t('account_recovery.pending.resend_success'))
          expect(response).to redirect_to(account_recovery_pending_url)
        end

        it 'blocks repeated sends once the shared request limit is reached' do
          RateLimiter.new(
            user: user,
            rate_limit_type: :account_recovery_request,
          ).increment_to_limited!

          expect { post :resend }.not_to change { ActionMailer::Base.deliveries.size }
          expect(flash[:error]).to eq(t('account_recovery.pending.resend_rate_limited'))
          expect(response).to redirect_to(account_recovery_pending_url)
        end

        it 'does not report success if email delivery raises an error' do
          delivery = instance_double(ActionMailer::MessageDelivery)
          allow(UserMailer).to receive(:with).and_return(
            double(account_recovery_request: delivery),
          )
          allow(delivery).to receive(:deliver_now_or_later)
            .and_raise(Net::SMTPFatalError.new('Notification delivery failed'))

          expect { post :resend }.to raise_error(Net::SMTPFatalError)
          expect(flash[:success]).to be_nil
          expect(recovery_request.reload).to be_active
        end
      end
    end
  end

  describe '#show' do
    it 'redirects to root if the user is not signed in' do
      get :show

      expect(response).to redirect_to root_url
    end

    context 'when signed in before 2FA' do
      before { stub_sign_in_before_2fa(user) }

      context 'without an active recovery request' do
        it 'renders a 404' do
          get :show

          expect(response).to render_template('pages/page_not_found')
        end
      end

      context 'when a terminal recovery request exists' do
        before { create(:account_recovery_request, :cancelled, user: user) }

        it 'renders a 404' do
          get :show

          expect(response).to render_template('pages/page_not_found')
        end
      end

      context 'with an active recovery request' do
        before { create(:account_recovery_request, :waiting, user: user) }

        it 'renders the pending page' do
          get :show

          expect(response).to render_template(:show)
        end

        it 'assigns the waiting period interval' do
          get :show

          expect(controller.view_assigns['waiting_period_interval']).to be_present
        end

        it 'assigns only the email address used to sign in' do
          signed_in_email = create(:email_address, user: user, last_sign_in_at: Time.zone.now)
          create(:email_address, user: user)
          create(:email_address, user: user, confirmed_at: nil)
          create(:email_address)

          get :show

          expect(controller.view_assigns['email']).to eq(signed_in_email.email)
        end

        it 'does not cancel the request when rendering the pending page' do
          recovery_request = AccountRecoveryRequest.active_for_user(user)

          get :show

          expect(recovery_request.reload).to be_active
        end

        it 'does not send more notifications when the confirmation page is refreshed' do
          expect do
            get :show
            get :show
          end.not_to change { ActionMailer::Base.deliveries.size }
        end
      end
    end
  end
end
