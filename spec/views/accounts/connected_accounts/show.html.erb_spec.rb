require 'rails_helper'

RSpec.describe 'accounts/connected_accounts/show.html.erb' do
  let(:user) { create(:user, :fully_registered, :with_personal_key) }
  let(:feature_select_email_to_share_enabled) { true }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(IdentityConfig.store).to receive(:feature_select_email_to_share_enabled)
      .and_return(feature_select_email_to_share_enabled)
    assign(
      :presenter,
      AccountShowPresenter.new(
        decrypted_pii: nil,
        user: user,
        sp_session_request_url: nil,
        authn_context: nil,
        sp_name: nil,
        locked_for_session: false,
        all_emails_requested: false,
        ial2_requested: false,
      ),
    )
  end

  it 'renders a blank page' do
    # Blank page may not be the ideal behavior, but it's the expected one.
    # See: LG-3504
    render

    expect(rendered).to have_content(t('headings.account.connected_accounts'))
    expect(rendered).to have_css('ul:not(:has(li))')
  end

  context 'with a connected app' do
    let!(:identity) { create(:service_provider_identity, user:) }

    it 'lists applications with link to revoke' do
      render

      expect(rendered).to have_css('li', count: user.identities.count)

      page = Capybara.string(rendered.html)
      within page.find_css('li', text: user.identities.first.display_name) do
        expect(rendered).to have_link(t('account.revoke_consent.link_title'))
      end
    end

    it 'renders option to change email' do
      render

      expect(rendered).to have_content(t('account.connected_apps.email_not_selected'))
      expect(rendered).to have_link(
        t('help_text.requested_attributes.change_email_link'),
        href: edit_connected_account_selected_email_path(identity_id: identity.id),
      )
    end

    context 'with selected email to share feature disabled' do
      let(:feature_select_email_to_share_enabled) { false }

      it 'does not render option to change email' do
        render

        expect(rendered).not_to have_content(t('account.connected_apps.email_not_selected'))
        expect(rendered).not_to have_link(
          t('help_text.requested_attributes.change_email_link'),
          href: edit_connected_account_selected_email_path(identity_id: identity.id),
        )
      end
    end

    context 'with connected app having linked email' do
      let(:email_address) { user.confirmed_email_addresses.take }
      let!(:identity) do
        create(:service_provider_identity, user:, email_address_id: email_address.id)
      end

      it 'renders associated email with option to change' do
        render

        expect(rendered).to have_content(email_address.email)
        expect(rendered).to have_link(
          t('help_text.requested_attributes.change_email_link'),
          href: edit_connected_account_selected_email_path(identity_id: identity.id),
        )
      end

      context 'with selected email to share feature disabled' do
        let(:feature_select_email_to_share_enabled) { false }

        it 'does not render associated email' do
          render

          expect(rendered).not_to have_content(email_address.email)
        end
      end
    end
  end

  context 'with a connected app that is an invalid service provider' do
    before do
      user.identities << create(:service_provider_identity, :active, service_provider: 'aaaaa')
    end

    it 'renders' do
      expect { render }.to_not raise_error
      expect(rendered).to match '</lg-time>'
      expect(rendered).to_not include('&lt;')
    end
  end
end
