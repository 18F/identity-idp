require 'rails_helper'

RSpec.describe 'accounts/connected_services/show.html.erb' do
  let(:user) { create(:user, :fully_registered, :with_personal_key) }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
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

  it 'does not render the NDS connected services in the default layout' do
    render

    expect(rendered).not_to have_css('.dashboard-home')
    expect(rendered).not_to have_css('.connected-services')
  end

  it 'renders a blank page' do
    # Blank page may not be the ideal behavior, but it's the expected one.
    # See: LG-3504
    render

    expect(rendered).to have_content(t('headings.account.connected_services'))
    expect(rendered).to have_css('ul:not(:has(li))')
  end

  describe 'the America.gov delegation section' do
    before do
      allow(IdentityConfig.store).to receive(:sts_consent_expiration_in_days).and_return(365)
    end

    let(:heading) do
      t('account.navigation.america_gov_services', america_gov_name: AMERICA_GOV_NAME)
    end

    context 'without an STS consent' do
      it 'hides the section' do
        render

        expect(rendered).to_not have_content(heading)
      end
    end

    context 'with an expired STS consent' do
      before { create(:user_consent_sts, user:, created_at: 366.days.ago) }

      it 'hides the section' do
        render

        expect(rendered).to_not have_content(heading)
      end
    end

    context 'with an unexpired STS consent' do
      let!(:consent) { create(:user_consent_sts, user:, created_at: 3.days.ago) }

      it 'shows the section with the consent date and a disconnect link' do
        render

        expect(rendered).to have_content(heading)
        expect(rendered).to have_content(
          consent.created_at.in_time_zone.utc.strftime(t('time.formats.event_timestamp')),
        )
        expect(rendered).to have_link(t('account.revoke_consent.link_title'))
        expect(rendered).to have_css(
          "a[href*='#{sts_consent_revoke_path(id: consent.id)}']",
        )
      end

      it 'links the card heading to the service in a new tab' do
        render

        expect(rendered).to have_css(
          "a.usa-link--external[href='https://mytravel.state.gov/'][target=_blank]",
          text: 'MyTravelGov',
        )
        expect(rendered).to have_content(t('links.new_tab'))
      end

      it 'renders one card per consent' do
        create(:user_consent_sts, user:)

        render

        expect(rendered).to have_css('li', text: 'MyTravelGov', count: 2)
      end
    end
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

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      allow(IdentityConfig.store).to receive(:sts_consent_expiration_in_days).and_return(365)
    end

    let(:page) { Capybara.string(rendered) }

    it 'renders the connected services heading and description' do
      render

      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css(
        '.dashboard-home .connected-services h1.connected-services__heading',
        text: t('headings.account.connected_services'),
      )
      expect(rendered).to have_css(
        '.connected-services__description',
        text: t('nds.dashboard_home.connected_services_description', app_name: APP_NAME),
      )
    end

    it 'renders no agency list without connected agencies' do
      render

      expect(rendered).not_to have_css('.connected-services__list')
      expect(rendered).not_to have_css('.discovery-service')
    end

    context 'with a connected agency' do
      let!(:identity) do
        create(:service_provider_identity, user:, verified_attributes: ['email'])
      end
      let(:row) { page.find('li.discovery-service', text: identity.display_name) }

      it 'renders a connected row with the agency seal, name and connection date' do
        render

        expect(rendered).to have_css(
          '.connected-services__list .connected-services__rows ' \
            'li.discovery-service.discovery-service--connected',
          count: 1,
        )
        expect(row).to have_css(
          "img.agency-seal.discovery-service__logo[alt=''][src='" \
            "#{identity.service_provider_record.logo_url}']",
        )
        expect(row).to have_css('.discovery-service__title', text: identity.display_name)
        expect(row).to have_css(
          '.discovery-service__description lg-time',
          text: identity.created_at.utc.strftime(t('time.formats.event_timestamp')),
        )
      end

      it 'shows that no email is selected yet' do
        render

        expect(row).to have_css(
          '.discovery-service__description',
          text: t('account.connected_apps.email_not_selected'),
        )
      end

      it 'renders a named menu with manage preferences and disconnect links' do
        render

        summary = row.find('details.connected-service__menu > summary')
        expect(summary[:class].split).to include(
          'usa-button', 'usa-button--secondary', 'usa-button--icon-only'
        )
        expect(summary).to have_css(
          '.usa-sr-only',
          text: t('nds.dashboard_home.service_options', sp_name: identity.display_name),
        )
        expect(row).to have_link(
          t('nds.dashboard_home.manage_preferences'),
          href: edit_connected_service_selected_email_path(identity_id: identity.id),
          class: 'popover-menu__item',
          visible: :all,
        )
        expect(row).to have_link(
          t('account.revoke_consent.link_title'),
          href: service_provider_revoke_url(sp_id: identity.service_provider_id),
          class: %w[popover-menu__item connected-service__menu-item--danger],
          visible: :all,
        )
      end

      it 'does not link the agency name or render the legacy change link' do
        render

        expect(row).not_to have_link(identity.display_name)
        expect(rendered).not_to have_link(t('help_text.requested_attributes.change_email_link'))
      end

      context 'when the agency has a selected email' do
        let(:email_address) { user.confirmed_email_addresses.take }
        let!(:identity) do
          create(
            :service_provider_identity,
            user:,
            email_address_id: email_address.id,
            verified_attributes: ['email'],
          )
        end

        it 'shows the shared email' do
          render

          expect(row).to have_css('.discovery-service__description', text: email_address.email)
          expect(row).not_to have_content(t('account.connected_apps.email_not_selected'))
        end
      end

      context 'when the agency requests all emails' do
        before { identity.update(verified_attributes: ['all_emails']) }

        it 'shows no email and only offers disconnect' do
          render

          expect(row).not_to have_content(t('account.connected_apps.email_not_selected'))
          expect(row).not_to have_link(
            t('nds.dashboard_home.manage_preferences'),
            visible: :all,
          )
          expect(row).to have_link(t('account.revoke_consent.link_title'), visible: :all)
        end
      end

      context 'after the shared email was updated' do
        before { flash[:email_updated_identity_id] = identity.id }

        it 'renders the success alert above the heading' do
          render

          expect(page).to have_css(
            '.dashboard-home > .usa-alert--success',
            text: strip_tags(
              t('account.connected_apps.email_update_success_html', sp_name: identity.display_name),
            ),
          )
        end
      end

      it 'does not render the success alert without the flash' do
        render

        expect(rendered).not_to have_css('.usa-alert--success')
      end
    end

    describe 'the America.gov services section' do
      let(:heading) do
        t('account.navigation.america_gov_services', america_gov_name: AMERICA_GOV_NAME)
      end

      it 'is hidden without an STS consent' do
        render

        expect(rendered).not_to have_css('h2', text: heading)
      end

      context 'with an unexpired STS consent' do
        let!(:consent) { create(:user_consent_sts, user:, created_at: 3.days.ago) }
        let(:section) { page.find('section', text: heading) }

        it 'renders the section heading and description' do
          render

          expect(section).to have_css('h2.connected-services__heading', text: heading)
          expect(section).to have_css(
            '.connected-services__description',
            text: t(
              'nds.dashboard_home.delegations_description',
              america_gov_name: AMERICA_GOV_NAME,
            ),
          )
        end

        it 'renders a row with the service, its connection date and an edit button' do
          render

          row = section.find('li.discovery-service.discovery-service--connected')
          expect(row).to have_css("img.agency-seal[alt='']")
          expect(row).to have_css('.discovery-service__title', text: 'MyTravelGov')
          expect(row).to have_css(
            '.discovery-service__description',
            text: consent.created_at.in_time_zone.utc.strftime(t('time.formats.event_timestamp')),
          )
          expect(row).to have_link(
            t('forms.buttons.edit'),
            href: sts_consent_revoke_url(id: consent.id),
            class: %w[usa-button usa-button--secondary],
          )
        end

        it 'renders one row per consent' do
          create(:user_consent_sts, user:)

          render

          expect(section).to have_css('li.discovery-service', count: 2)
        end
      end
    end
  end
end
