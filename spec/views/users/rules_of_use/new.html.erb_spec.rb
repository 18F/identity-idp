require 'rails_helper'

RSpec.describe 'users/rules_of_use/new.html.erb' do
  let(:user) { create(:user, :fully_registered) }
  let(:cancel_link_url) { 'https://example.com/cancel' }
  let(:decorated_sp_session) do
    instance_double(ServiceProviderSession, cancel_link_url: cancel_link_url)
  end

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)
    @rules_of_use_form = RulesOfUseForm.new(user)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.registrations.new'))

    render
  end

  context 'in the default layout' do
    it 'renders the rules of use heading and overview with a new-tab link' do
      render

      expect(rendered).to have_css('h1', text: t('titles.rules_of_use'))
      expect(rendered).to have_link(
        t('titles.rules_of_use'),
        href: MarketingSite.rules_of_use_url,
        count: 2,
      )
      expect(rendered).to have_content(
        strip_tags(t('users.rules_of_use.details_html', app_name: APP_NAME)).squish,
        normalize_ws: true,
      )
    end

    it 'renders the required terms checkbox posting to the rules of use path' do
      render

      expect(rendered).to have_css("form[action='#{rules_of_use_path}'][method='post']")
      expect(rendered).to have_css(
        'lg-validated-field input[type=checkbox]' \
          '[name="rules_of_use_form[terms_accepted]"][required]',
      )
      expect(rendered).to have_button(t('forms.buttons.continue'))
    end

    it 'renders a cancel link to the service provider cancel url' do
      render

      expect(rendered).to have_link(t('links.cancel'), href: cancel_link_url)
    end

    it 'does not render the NDS form-page card' do
      render

      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the rules of use heading' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth--form-page h1', text: t('titles.rules_of_use'))
      expect(rendered).to have_css('h1', count: 1)
    end

    it 'renders the overview subtitle with a new-tab rules of use link' do
      render

      expect(rendered).to have_css(
        ".auth__intro-description a[href='#{MarketingSite.rules_of_use_url}'][target=_blank]",
        text: t('titles.rules_of_use'),
      )
    end

    it 'renders the rules of use details below a divider' do
      render

      expect(rendered).to have_css('.auth__form-page-body hr.divider')
      expect(rendered).to have_css('.auth__form-page-body .copy ul li', count: 4)
    end

    it 'posts the required terms checkbox in a card to the rules of use path' do
      render

      expect(rendered).to have_css("form[action='#{rules_of_use_path}'][method='post']")
      expect(rendered).to have_css(
        '.auth__form-page-body .card lg-validated-field ' \
          'input.usa-checkbox__input[type=checkbox][value="1"]' \
          '[name="rules_of_use_form[terms_accepted]"][required]',
      )
      expect(rendered).to have_css(
        'input[type=hidden][name="rules_of_use_form[terms_accepted]"][value="0"]',
        visible: :all,
      )
      expect(rendered).to have_css(
        '.card label.usa-checkbox__label',
        text: t('users.rules_of_use.check_box_to_accept', app_name: APP_NAME),
      )
      expect(rendered).to have_css(
        ".card label a[href='#{MarketingSite.rules_of_use_url}'][target=_blank]",
        text: t('titles.rules_of_use'),
      )
    end

    it 'renders a Continue submit and a tertiary cancel button' do
      render

      expect(rendered).to have_css(
        '.auth__actions .actions button.usa-button[type=submit]',
        text: t('forms.buttons.continue'),
      )
      expect(rendered).to have_css(
        ".auth__actions .actions a.usa-button.usa-button--tertiary[href='#{cancel_link_url}']",
        text: t('links.cancel'),
      )
    end

    it 'does not render the legacy cancel footer or page heading' do
      render

      expect(rendered).to_not have_css('.page-footer')
      expect(rendered).to_not have_css('.page-heading')
    end

    context 'when the user has not set up MFA yet' do
      let(:user) { create(:user) }

      it 'cancels account creation' do
        render

        expect(rendered).to have_css(
          ".auth__actions a.usa-button[href='#{sign_up_cancel_path}']",
          text: t('links.cancel_account_creation'),
        )
      end
    end

    context 'when the terms were not accepted' do
      before { @rules_of_use_form.submit(terms_accepted: '0') }

      it 'renders the required checkbox error tied to the checkbox' do
        render

        doc = Nokogiri::HTML(rendered)
        checkbox = doc.at_css('input[type=checkbox][name="rules_of_use_form[terms_accepted]"]')
        error = doc.at_css('.card .usa-error-message')

        expect(error.text.strip).to eq(t('forms.validation.required_checkbox'))
        expect(checkbox[:'aria-invalid']).to eq('true')
        expect(checkbox[:'aria-describedby']).to include(error[:id])
      end
    end
  end
end
