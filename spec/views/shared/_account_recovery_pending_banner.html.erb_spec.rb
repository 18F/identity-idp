require 'rails_helper'

RSpec.describe 'shared/_account_recovery_pending_banner.html.erb' do
  let(:user) { create(:user, :fully_registered) }

  subject(:rendered) { render partial: 'shared/account_recovery_pending_banner' }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:user_fully_authenticated?).and_return(false)
  end

  context 'with no recovery request' do
    it 'renders nothing' do
      expect(rendered).to be_blank
    end
  end

  # CancelRequest stops at link redemption, so these are the only states where
  # the banner's "authenticating cancels the request" promise holds.
  [nil, :waiting, :granted].each do |trait|
    context "with a #{trait || 'requested'} request" do
      before do
        if trait
          create(:account_recovery_request, trait, user: user)
        else
          create(:account_recovery_request, user: user)
        end
      end

      it 'tells the user that authenticating cancels the request' do
        expect(rendered).to have_content(
          t('account_recovery.pending.mfa_banner', app_name: APP_NAME),
        )
      end
    end
  end

  context 'with a link_verified request' do
    before { create(:account_recovery_request, :link_verified, user: user) }

    it 'does not promise that authenticating cancels the request' do
      expect(rendered).to have_content(t('account_recovery.pending.link_verified_banner'))
      expect(rendered).not_to have_content(
        t('account_recovery.pending.mfa_banner', app_name: APP_NAME),
      )
    end
  end

  context 'with a replacement_mfa_pending request' do
    before { create(:account_recovery_request, :replacement_mfa_pending, user: user) }

    # The user is enrolling replacement MFA. Authenticating there completes
    # recovery rather than cancelling it, so neither banner applies.
    it 'renders nothing' do
      expect(rendered).to be_blank
    end
  end

  context 'when the user is fully authenticated' do
    before do
      allow(view).to receive(:user_fully_authenticated?).and_return(true)
      create(:account_recovery_request, :waiting, user: user)
    end

    it 'renders nothing' do
      expect(rendered).to be_blank
    end
  end

  context 'with no current user' do
    before { allow(view).to receive(:current_user).and_return(nil) }

    it 'renders nothing' do
      expect(rendered).to be_blank
    end
  end
end
