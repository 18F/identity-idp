require 'rails_helper'

describe 'accounts/two_factor_authentication/show.html.erb' do
  let(:user) { create(:user, :signed_up, :with_personal_key) }
  let(:decorated_user) { user.decorate }

  before do
    allow(user).to receive(:decorate).and_return(decorated_user)
    allow(view).to receive(:current_user).and_return(user)
    assign(
      :presenter,
      AccountShowPresenter.new(
        decrypted_pii: nil, personal_key: nil, decorated_user: decorated_user,
        sp_session_request_url: nil, sp_name: nil,
        locked_for_session: false
      ),
    )
  end

  context 'user is not TOTP enabled' do
    it 'contains link to enable TOTP' do
      render

      expect(rendered).to have_link(t('account.index.auth_app_add'), href: authenticator_setup_url)
      expect(rendered).not_to have_xpath("//input[@value='Disable']")
    end
  end

  context 'when user is TOTP enabled' do
    let(:user) { create(:user, :signed_up, :with_authentication_app) }

    before do
      assign(
        :presenter,
        AccountShowPresenter.new(
          decrypted_pii: nil, personal_key: nil, decorated_user: decorated_user,
          sp_session_request_url: nil, sp_name: nil,
          locked_for_session: false
        ),
      )
    end

    it 'contains link to disable TOTP' do
      render

      expect(rendered).to have_link(t('forms.buttons.disable', href: auth_app_delete_path))
    end
  end

  context 'when the user does not have password_reset_profile' do
    before do
      allow(decorated_user).to receive(:password_reset_profile).and_return(false)
    end

    it 'contains a personal key section' do
      render

      expect(rendered).to have_content t('account.items.personal_key')
      expect(rendered).to have_link(
        t('account.links.regenerate_personal_key'),
        href: create_new_personal_key_url,
      )
    end
  end

  context 'when current user has password_reset_profile' do
    before do
      allow(decorated_user).to receive(:password_reset_profile).and_return(true)
    end

    it 'lacks a personal key section' do
      render

      expect(rendered).to_not have_content t('account.items.personal_key')
      expect(rendered).to_not have_link(
        t('account.links.regenerate_personal_key'), href: manage_personal_key_path
      )
    end
  end

  context 'when multiple mfa is enabled' do
    let(:user) { create(:user, :with_phone, :with_authentication_app) }
    before do
      allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return true
      assign(
        :presenter,
        AccountShowPresenter.new(
          decrypted_pii: nil, personal_key: nil, decorated_user: decorated_user,
          sp_session_request_url: nil, sp_name: nil,
          locked_for_session: false
        ),
      )
    end

    it 'disables delete buttons for the last non restricted mfa method with phone configured' do
      render

      expect(rendered).to_not have_link(t('forms.buttons.disable', href: auth_app_delete_path))
    end
  end
end
