require 'rails_helper'

RSpec.describe 'accounts/two_factor_authentication/show.html.erb' do
  let(:user) { create(:user, :fully_registered, :with_personal_key) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    assign(
      :presenter,
      AccountShowPresenter.new(
        decrypted_pii: nil, personal_key: nil, user: user,
        sp_session_request_url: nil, sp_name: nil,
        locked_for_session: false
      ),
    )
  end

  context 'user is not TOTP enabled' do
    it 'contains link to enable TOTP' do
      render

      expect(rendered).to have_link(t('account.index.auth_app_add'), href: authenticator_setup_url)
      expect(rendered).not_to have_link(t('forms.buttons.disable'))
    end
  end

  context 'when user is TOTP enabled' do
    let(:user) { create(:user, :fully_registered, :with_authentication_app) }

    before do
      assign(
        :presenter,
        AccountShowPresenter.new(
          decrypted_pii: nil, personal_key: nil, user: user,
          sp_session_request_url: nil, sp_name: nil,
          locked_for_session: false
        ),
      )
    end

    it 'contains link to disable TOTP' do
      render

      expect(rendered).to have_link(
        t('forms.buttons.disable'),
        href: auth_app_delete_path(id: user.auth_app_configurations.first.id),
      )
    end
  end

  context 'when the user does not have password_reset_profile' do
    before do
      allow(user).to receive(:password_reset_profile).and_return(false)
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
      allow(user).to receive(:password_reset_profile).and_return(true)
    end

    it 'lacks a personal key section' do
      render

      expect(rendered).to_not have_content t('account.items.personal_key')
      expect(rendered).to_not have_link(
        t('account.links.regenerate_personal_key'), href: manage_personal_key_path
      )
    end
  end
end
