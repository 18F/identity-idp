require 'rails_helper'

RSpec.describe 'accounts/connected_services/show.html.erb' do
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

  it 'renders a blank page' do
    # Blank page may not be the ideal behavior, but it's the expected one.
    # See: LG-3504
    render

    expect(rendered).to have_content(t('headings.account.connected_services'))
    expect(rendered).to have_css('ul:not(:has(li))')
  end

  context 'with a connected app' do
    let!(:identity) { create(:service_provider_identity, user:, verified_attributes: ['email']) }

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
        href: edit_connected_service_selected_email_path(identity_id: identity.id),
      )
    end

    context 'when the partner requests all_emails' do
      before { identity.update(verified_attributes: ['all_emails']) }

      it 'does not show the change link' do
        render

        expect(rendered).not_to have_content(t('account.connected_apps.email_not_selected'))
        expect(rendered).not_to have_link(
          t('help_text.requested_attributes.change_email_link'),
          href: edit_connected_service_selected_email_path(identity_id: identity.id),
        )
      end
    end

    context 'when the partner does not request email' do
      before { identity.update(verified_attributes: ['ssn']) }

      it 'hides the change link' do
        render

        expect(rendered).not_to have_content(t('account.connected_apps.email_not_selected'))
        expect(rendered).to_not have_link(
          t('help_text.requested_attributes.change_email_link'),
          href: edit_connected_service_selected_email_path(identity_id: identity.id),
        )
      end
    end

    context 'with connected app having linked email' do
      let(:email_address) { user.confirmed_email_addresses.take }
      let!(:identity) do
        create(
          :service_provider_identity,
          user:,
          email_address_id: email_address.id,
          verified_attributes: ['email'],
        )
      end

      it 'renders associated email with option to change' do
        render

        expect(rendered).to have_content(email_address.email)
        expect(rendered).to have_link(
          t('help_text.requested_attributes.change_email_link'),
          href: edit_connected_service_selected_email_path(identity_id: identity.id),
        )
      end
    end

    context 'when another identity references a missing service provider' do
      before do
        create(
          :service_provider_identity,
          user:,
          service_provider_record: nil,
          service_provider: 'urn:gov:gsa:missing-service-provider',
        )
      end

      it 'renders only connected apps with existing service providers' do
        expect { render }.not_to raise_error

        expect(rendered).to have_css('li', count: 1)
        expect(rendered).to have_content(identity.display_name)
      end
    end
  end

  context 'with a connected service provider approved for delegation' do
    let(:service_provider) do
      create(
        :service_provider, :delegation_service_provider, issuer: 'urn:mybenefits',
                                                         friendly_name: 'MyBenefits Assistant'
      )
    end
    let(:agency) { create(:agency, name: 'Department of Housing Support') }
    let(:application) do
      create(
        :service_provider, :delegation_application, issuer: 'urn:housing-records',
                                                    friendly_name: 'Housing Assistance Records',
                                                    agency: agency,
                                                    allowed_delegation_service_providers: [
                                                      'urn:mybenefits',
                                                    ]
      )
    end
    let!(:service_provider_identity) do
      create(
        :service_provider_identity, user:, service_provider: service_provider.issuer,
                                    verified_attributes: ['email']
      )
    end
    let!(:application_identity) do
      create(
        :service_provider_identity, user:, service_provider: application.issuer,
                                    verified_attributes: ['email']
      )
    end

    before do
      allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
    end

    it 'renders a toggle per application grouped by agency and a confirmation modal' do
      toggle_path = connected_services_token_exchange_grant_path(
        identity_id: service_provider_identity.id,
      )
      render

      page = Capybara.string(rendered.html)
      expect(page.find_css('[data-delegation-manage]').size).to eq(1)

      expect(rendered).to have_content(
        t('account.connected_apps.token_exchange.heading', sp: 'MyBenefits Assistant'),
      )
      expect(rendered).to have_content('Department of Housing Support')
      expect(rendered).to have_css(
        "form[action='#{toggle_path}'] " \
        "input[name='application_issuer'][value='urn:housing-records']",
        visible: false,
      )
      expect(rendered).to have_css("[data-delegation-toggle][aria-checked='false']")
      expect(rendered).to have_css('lg-modal.delegation-consent-modal', visible: false)
      expect(rendered).to have_content(t('account.connected_apps.token_exchange.modal.confirm'))
    end

    it 'shows an existing approval as on, with the date it was given' do
      TokenExchangeGrant.approve!(
        user:, service_provider:, application:, source: 'account_page', remember: true,
        now: 2.months.ago
      )

      render

      expect(rendered).to have_css("[data-delegation-toggle][aria-checked='true']")
      expect(rendered).to have_content(t('account.connected_apps.token_exchange.on'))
    end

    it 'renders the confirmation modal inside the block in the NDS layout too' do
      allow(view).to receive(:nds_layout?).and_return(true)
      render
      page = Capybara.string(rendered.html)
      expect(page.find_css('[data-delegation-manage] lg-modal').size).to eq(1)
    end

    it 'renders no management block for a connected app not approved for delegation' do
      service_provider.update!(token_exchange_enabled_sp: false)
      render
      expect(rendered).not_to have_css('[data-delegation-manage]')
    end
  end
end
