require 'rails_helper'

RSpec.describe 'accounts/two_factor_authentication/show.html.erb' do
  let(:user) { create(:user, :fully_registered, :with_personal_key) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    assign(
      :presenter,
      AccountShowPresenter.new(
        decrypted_pii: nil,
        user: user,
        sp_session_request_url: nil,
        authn_context: nil,
        sp_name: nil,
        locked_for_session: false,
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

    it 'renders a manage link to the auth app edit page and the created date' do
      configuration = user.auth_app_configurations.first

      render

      expect(rendered).to have_content(configuration.name)
      expect(rendered).to have_content(
        t(
          'account.dashboard.auth_methods.created_on',
          date: I18n.l(configuration.created_at, format: :event_date),
        ),
      )
      expect(rendered).to have_link(href: edit_auth_app_path(id: configuration.id))
    end
  end

  it 'does not render a personal key section' do
    render

    expect(rendered).to_not have_content(t('account.items.personal_key'))
    expect(rendered).to_not have_link(
      t('account.links.regenerate_personal_key'),
      href: create_new_personal_key_url,
    )
  end
end
