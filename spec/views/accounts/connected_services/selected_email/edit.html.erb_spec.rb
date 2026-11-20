require 'rails_helper'

RSpec.describe 'accounts/connected_services/selected_email/edit.html.erb' do
  let(:identity) { create(:service_provider_identity, :active) }
  let(:user) do
    create(
      :user,
      email_addresses: [
        create(:email_address),
        create(:email_address),
        create(:email_address, :unconfirmed),
      ],
      identities: [identity],
    )
  end

  subject(:rendered) { render }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:current_user).and_return(user)
    @identity = identity
    @select_email_form = SelectEmailForm.new(user:, identity:)
    @can_add_email = true
  end

  it 'does not render the NDS form page in the default layout' do
    expect(rendered).not_to have_css('.auth--form-page')
    expect(rendered).not_to have_css('.radio-group')
  end

  it 'renders introduction text' do
    expect(rendered).to have_content(
      strip_tags(t('help_text.select_preferred_email_html', sp: identity.display_name)),
    )
  end

  it 'renders a list of the users email addresses as radio options' do
    allow(self).to receive(:page).and_return(Capybara.string(rendered))
    inputs = page.find_all('[type="radio"]')
    expect(inputs.count).to eq(2)
    expect(inputs).to be_logically_grouped(t('titles.select_email'))
    expect(rendered).to have_content(identity.display_name)
  end

  it 'renders a button to allow users to add email' do
    expect(rendered).to have_link(
      t('account.index.email_add'),
      href: add_email_path(in_select_email_flow: true),
    )
  end

  context 'if user has reached max number of emails' do
    before do
      @can_add_email = false
    end

    it 'does not render add email button' do
      expect(rendered).not_to have_link(
        t('account.index.email_add'),
        href: add_email_path(in_select_email_flow: true),
      )
    end
  end

  context 'in the NDS layout' do
    let(:page) { Capybara.string(rendered) }
    let(:confirmed_emails) { user.confirmed_email_addresses }

    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      @email_id = confirmed_emails.last.id
    end

    it 'asks for the signed-in header' do
      rendered

      expect(view.content_for(:nds_account_header)).to eq('true')
    end

    it 'renders the agency name as the page heading' do
      expect(page).to have_css('h1', count: 1)
      expect(page).to have_css('.auth--form-page h1', text: identity.display_name)
    end

    it 'renders the preferred email section heading and description' do
      expect(page).to have_css(
        'h2#select-email-heading.connected-services__heading',
        text: t('nds.dashboard_home.preferred_email'),
      )
      expect(page).to have_css(
        'p#select-email-intro.connected-services__description',
        text: strip_tags(t('help_text.select_preferred_email_html', sp: identity.display_name)),
      )
    end

    it 'renders the confirmed emails as a labelled radio group' do
      fieldset = page.find(
        "fieldset[aria-labelledby='select-email-heading']" \
          "[aria-describedby='select-email-intro']",
      )
      inputs = fieldset.find_all(
        '.radio-group .radio input.radio__input[type=radio]',
        visible: :all,
      )

      expect(inputs.map(&:value)).to match_array(confirmed_emails.map { |email| email.id.to_s })
      expect(inputs.map { |input| input[:name] }.uniq).to eq(
        ['select_email_form[selected_email_id]'],
      )
      expect(inputs).to all(satisfy { |input| input[:required] })
      confirmed_emails.each do |email|
        expect(fieldset).to have_css('label.radio__label', text: email.email)
      end
      expect(fieldset).to have_checked_field(confirmed_emails.last.email, visible: :all)
    end

    it 'submits the selection to the same endpoint' do
      form_action = connected_services_selected_email_path(identity_id: identity.id)
      expect(page).to have_css(
        "form[action='#{form_action}'] input[name=_method][value=patch]",
        visible: :all,
      )
      expect(page).to have_button(
        t('components.manageable_authenticator.save'),
        type: 'submit',
        class: 'usa-button',
      )
    end

    it 'renders a cancel button back to the connected services page' do
      expect(page).to have_link(
        t('links.cancel'),
        href: account_connected_services_path,
        class: %w[usa-button usa-button--secondary],
      )
      expect(page).not_to have_link(t('forms.buttons.back'))
    end

    it 'renders the add email button' do
      expect(page).to have_link(
        t('account.index.email_add'),
        href: add_email_path(in_select_email_flow: true),
        class: %w[usa-button usa-button--tertiary],
      )
    end

    context 'if user has reached max number of emails' do
      before { @can_add_email = false }

      it 'does not render the add email button' do
        expect(page).not_to have_link(t('account.index.email_add'))
      end
    end
  end
end
