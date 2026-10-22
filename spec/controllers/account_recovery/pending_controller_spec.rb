require 'rails_helper'

RSpec.describe AccountRecovery::PendingController do
  let(:user) { create(:user, :fully_registered) }

  describe '#status' do
    it 'requires password authentication' do
      get :status

      expect(response).to redirect_to(root_url)
    end

    context 'when signed in before 2FA' do
      before { stub_sign_in_before_2fa(user) }

      it 'does not use another user’s request' do
        create(:account_recovery_request, :waiting)

        get :status

        expect(response).to render_template('pages/page_not_found')
      end

      it 'does not show a terminal request' do
        create(:account_recovery_request, :cancelled, user: user)

        get :status

        expect(response).to render_template('pages/page_not_found')
      end

      it 'shows time remaining from the original request' do
        freeze_time do
          allow(IdentityConfig.store).to receive(:account_recovery_wait_period_days).and_return(2)
          recovery_request = create(
            :account_recovery_request, :waiting, user: user, requested_at: 1.day.ago
          )
          original_attributes = recovery_request.attributes

          expect { get :status }.not_to change { ActionMailer::Base.deliveries.size }

          expect(response).to render_template(:status)
          expect(controller.view_assigns['pending_presenter'].time_remaining_until_granted)
            .to eq('1 day')
          expect(recovery_request.reload.attributes).to eq(original_attributes)

          travel 12.hours
          get :status

          expect(controller.view_assigns['pending_presenter'].time_remaining_until_granted)
            .to eq('12 hours')
        end
      end

      it 'does not display a negative countdown when the waiting period ends' do
        freeze_time do
          waiting_period = IdentityConfig.store.account_recovery_wait_period_days.days
          recovery_request = create(
            :account_recovery_request, :waiting,
            user: user,
            requested_at: Time.zone.now - waiting_period
          )

          get :status

          expect(controller.view_assigns['pending_presenter'].time_remaining_until_granted)
            .to eq('1 minute')
          travel 1.hour
          get :status

          expect(controller.view_assigns['pending_presenter'].time_remaining_until_granted)
            .to eq('1 minute')
          expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::WAITING)
        end
      end
    end
  end

  describe '#cancel' do
    it 'requires password authentication' do
      post :cancel

      expect(response).to redirect_to(root_url)
    end

    context 'when signed in before 2FA' do
      before { stub_sign_in_before_2fa(user) }

      it 'does not cancel another user’s request' do
        recovery_request = create(:account_recovery_request, :waiting)

        post :cancel

        expect(response).to render_template('pages/page_not_found')
        expect(recovery_request.reload).to be_active
      end

      it 'does not report success without an active request' do
        create(:account_recovery_request, :cancelled, user: user)

        post :cancel

        expect(response).to render_template('pages/page_not_found')
        expect(flash[:success]).to be_nil
      end

      it 'cancels the request' do
        recovery_request = create(:account_recovery_request, :granted, user: user)

        freeze_time do
          post :cancel

          expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::CANCELLED)
          expect(recovery_request.cancelled_at).to eq(Time.zone.now)
        end
        expect(response).to redirect_to(login_two_factor_options_url)
      end
    end
  end

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
          expect(Telephony).not_to receive(:send_account_recovery_notice)

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

      %i[link_verified password_verified replacement_mfa_pending].each do |state|
        it "does not show pending cancellation for a #{state} request" do
          create(:account_recovery_request, state, user: user)

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

      context 'with a granted request whose link has lapsed' do
        let!(:recovery_request) do
          create(
            :account_recovery_request,
            :granted,
            user: user,
            token_expires_at: Time.zone.now - 1.minute,
          )
        end

        it 'expires the request on page load and renders a 404' do
          get :show

          expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::EXPIRED)
          expect(response).to render_template('pages/page_not_found')
        end

        it 'frees the user to request recovery again' do
          get :show

          expect(AccountRecoveryRequest.active_for_user(user)).to be_nil
        end
      end

      context 'with a granted request whose link is still valid' do
        let!(:recovery_request) do
          create(
            :account_recovery_request,
            :granted,
            user: user,
            token_expires_at: Time.zone.now + 1.hour,
          )
        end

        it 'does not expire the request' do
          get :show

          expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::GRANTED)
        end
      end
    end
  end

  describe '#status' do
    it 'requires password authentication' do
      get :status

      expect(response).to redirect_to(root_url)
    end

    context 'when signed in before 2FA' do
      before { stub_sign_in_before_2fa(user) }

      it 'renders not found without an active request' do
        get :status

        expect(response).to render_template('pages/page_not_found')
      end

      it 'does not show another user’s request' do
        create(:account_recovery_request, :waiting)

        get :status

        expect(response).to render_template('pages/page_not_found')
      end

      %i[waiting granted].each do |state|
        it "renders for a #{state} request" do
          recovery_request = create(:account_recovery_request, state, user: user)

          get :status

          expect(response).to render_template(:status)
          expect(assigns(:pending_presenter).account_recovery_request).to eq(recovery_request)
        end
      end

      %i[link_verified password_verified cancelled].each do |state|
        it "renders not found for a #{state} request" do
          create(:account_recovery_request, state, user: user)

          get :status

          expect(response).to render_template('pages/page_not_found')
        end
      end

      it 'expires a lapsed grant instead of rendering' do
        recovery_request = create(
          :account_recovery_request,
          :granted,
          user: user,
          token_expires_at: 1.minute.ago,
        )

        get :status

        expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::EXPIRED)
        expect(response).to render_template('pages/page_not_found')
      end
    end
  end

  describe '#cancel' do
    before do
      allow(IdentityConfig.store).to receive(:deliver_mail_async).and_return(false)
    end

    it 'requires password authentication' do
      post :cancel

      expect(response).to redirect_to(root_url)
    end

    context 'when signed in before 2FA' do
      before { stub_sign_in_before_2fa(user) }

      it 'renders a 404 without an active request' do
        post :cancel

        expect(response).to render_template('pages/page_not_found')
      end

      %i[link_verified password_verified replacement_mfa_pending].each do |state|
        it "rejects cancellation of a #{state} request without sending a notification" do
          recovery_request = create(:account_recovery_request, state, user: user)
          original_attributes = recovery_request.attributes

          expect { post :cancel }.not_to change { ActionMailer::Base.deliveries.size }

          expect(response).to render_template('pages/page_not_found')
          expect(recovery_request.reload.attributes).to eq(original_attributes)
          expect(flash[:success]).to be_nil
        end
      end

      it 'allows cancellation of an unredeemed granted request' do
        recovery_request = create(:account_recovery_request, :granted, user: user)

        post :cancel

        expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::CANCELLED)
      end

      it 'rejects cancellation if token verification occurred after loading the request' do
        recovery_request = create(:account_recovery_request, :granted, user: user)
        allow(controller).to receive(:account_recovery_request).and_return(recovery_request)
        AccountRecoveryRequest.find(recovery_request.id)
          .transition_to!(AccountRecoveryRequest::LINK_VERIFIED)

        expect { post :cancel }.not_to change { ActionMailer::Base.deliveries.size }

        expect(response).to render_template('pages/page_not_found')
        expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::LINK_VERIFIED)
        expect(flash[:success]).to be_nil
      end

      context 'with an active recovery request' do
        let!(:recovery_request) { create(:account_recovery_request, :waiting, user: user) }

        it 'cancels the request and notifies the user' do
          expect { post :cancel }.to change { ActionMailer::Base.deliveries.size }.by(1)

          recovery_request.reload
          expect(recovery_request.state).to eq(AccountRecoveryRequest::CANCELLED)
          expect(recovery_request.cancel_reason).to eq('user_cancelled')
          expect(flash[:success]).to eq(t('account_recovery.pending.cancel_success'))
          expect(response).to redirect_to(login_two_factor_options_url)
        end

        it 'logs the cancellation' do
          stub_analytics

          post :cancel

          expect(@analytics).to have_logged_event(
            :account_recovery_cancelled,
            reason: 'user_cancelled',
            recovery_state: AccountRecoveryRequest::WAITING,
          )
        end

        it 'frees the user to request recovery again' do
          allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)

          post :cancel

          expect(AccountRecoveryRequest.active_for_user(user)).to be_nil
          expect(AccountRecovery::EligibilityPolicy.new(user: user).eligible?).to eq(true)
        end

        it 'does not alter the user’s authentication methods' do
          expect { post :cancel }
            .to_not change { user.reload.phone_configurations.count }
        end
      end
    end
  end
end
