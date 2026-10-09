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

  context 'with a connected broker' do
    let(:broker) do
      create(:service_provider, :active, issuer: 'broker.gov', friendly_name: 'Broker')
    end
    let(:agency) { create(:agency, name: 'Department of Benefits') }
    let(:target) do
      create(
        :service_provider, :active, issuer: 'target.gov', friendly_name: 'Benefits Portal',
                                    agency: agency, delegation_application: true,
                                    allowed_delegation_service_providers: ['broker.gov']
      )
    end
    let!(:broker_identity) do
      create(
        :service_provider_identity, user:, service_provider: broker.issuer,
                                    verified_attributes: ['email']
      )
    end
    let!(:target_identity) do
      create(
        :service_provider_identity, user:, service_provider: target.issuer,
                                    verified_attributes: ['email']
      )
    end

    before do
      allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
      allow(IdentityConfig.store).to receive(:token_exchange_service_providers)
        .and_return(['broker.gov'])
    end

    it 'renders per-application toggles by agency, an auto-enroll toggle, and a consent modal' do
      toggle_path = connected_services_token_exchange_grant_path(identity_id: broker_identity.id)
      render

      page = Capybara.string(rendered.html)
      manage = page.find_css('[data-token-exchange-manage]')
      expect(manage.size).to eq(1)

      expect(rendered).to have_content(
        t(
          'account.connected_apps.token_exchange.heading',
          sp: 'Broker',
        ),
      )
      expect(rendered).to have_content('Department of Benefits')
      expect(rendered).to have_css(
        "form[action='#{toggle_path}'] " \
        "input[name='target_issuer'][value='target.gov']",
        visible: false,
      )
      expect(rendered).to have_css("[data-token-exchange-toggle][aria-checked='false']", minimum: 2)
      expect(rendered).to have_css("input[name='grant_type'][value='auto_enroll']", visible: false)
      expect(rendered).to have_css('lg-modal.token-exchange-consent-modal', visible: false)
      expect(rendered).to have_content(t('account.connected_apps.token_exchange.modal.confirm'))
    end

    it 'shows an existing grant as on, with the date it was allowed' do
      granted_at = 2.months.ago
      TokenExchangeGrant.grant_one!(
        user:, broker_issuer: 'broker.gov', target_issuer: 'target.gov', granted_at:,
      )

      render

      expect(rendered).to have_css("[data-token-exchange-toggle][aria-checked='true']")
      expect(rendered).to have_content(t('account.connected_apps.token_exchange.on'))
    end

    it 'renders the consent modal inside the manage block in the NDS layout too' do
      allow(view).to receive(:nds_layout?).and_return(true)
      render
      page = Capybara.string(rendered.html)
      expect(page.find_css('[data-token-exchange-manage] lg-modal').size).to eq(1)
      expect(rendered).to have_css('[data-token-exchange-modal-body="auto_enroll"]', visible: false)
    end

    it 'renders no management block for a connected app that is not a broker' do
      allow(IdentityConfig.store).to receive(:token_exchange_service_providers).and_return([])
      render
      expect(rendered).not_to have_css('[data-token-exchange-manage]')
    end
  end
end
