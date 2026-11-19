require 'rails_helper'

RSpec.describe 'sign_up/select_email/show.html.erb' do
  subject(:rendered) { render }
  let(:email) { 'michael.motorist@email.com' }
  let(:email2) { 'michael.motorist2@email.com' }
  let(:user) { create(:user) }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    create(:email_address, email: email, user:)
    create(:email_address, email: email2, user:)
    @user_emails = user.confirmed_email_addresses
    @select_email_form = SelectEmailForm.new(user:)
    @sp_name = 'Test Service Provider'
    @can_add_email = true
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.select_email'))

    render
  end

  context 'in the default layout' do
    it 'renders introduction text' do
      expect(rendered).to have_content(
        strip_tags(t('help_text.select_preferred_email_html', sp: @sp_name)),
      )
    end

    it 'shows all of the emails' do
      expect(rendered).to include('michael.motorist@email.com')
      expect(rendered).to include('michael.motorist2@email.com')
    end

    it 'renders a button to allow users to add email' do
      expect(rendered).to have_link(
        t('account.index.email_add'),
        href: add_email_path(in_select_email_flow: true),
      )
    end

    it 'renders origin/main outline classes, no nds variant modifier' do
      expect(rendered).to have_css('.usa-button--outline.usa-button--big.usa-button--wide')
      expect(rendered).not_to have_css('.usa-button--quaternary')
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

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      @email_id = @user_emails.last.id
    end

    it 'renders the form-page card with the heading and intro' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css('.auth__intro h1', text: t('titles.select_email'))
      expect(rendered).to have_css(
        '.auth__intro-description #select-email-intro strong',
        text: @sp_name,
      )
    end

    it 'renders a radio for each email on the same param, checking the current one' do
      expect(rendered).to have_css("form[action='#{sign_up_select_email_path}'][method='post']")
      expect(rendered).to have_css(
        'fieldset[aria-describedby="select-email-intro"] legend.usa-sr-only',
        text: t('titles.select_email'),
      )
      expect(rendered).to have_css(
        ".radio input.radio__input[name='select_email_form[selected_email_id]']",
        count: @user_emails.size,
      )
      expect(rendered).to have_field(email, type: 'radio', checked: false)
      expect(rendered).to have_field(email2, type: 'radio', checked: true)
    end

    it 'marks every email radio required and valid until validated' do
      expect(rendered).to have_css(
        ".radio input.radio__input[name='select_email_form[selected_email_id]']" \
          "[required][aria-invalid='false']",
        count: @user_emails.size,
      )
    end

    it 'renders the select, add email and back actions' do
      expect(rendered).to have_css(
        '.auth__actions button[type=submit]',
        text: t('help_text.requested_attributes.select_email_link'),
      )
      add_email_url = add_email_path(in_select_email_flow: true)
      expect(rendered).to have_css(
        ".auth__actions a.usa-button--secondary[href='#{add_email_url}']",
        text: t('account.index.email_add'),
      )
      expect(rendered).to have_css(
        ".auth__actions a.usa-button--tertiary[href='#{sign_up_completed_path}']",
        text: t('forms.buttons.back'),
      )
    end

    context 'if user has reached max number of emails' do
      before do
        @can_add_email = false
      end

      it 'does not render add email button' do
        expect(rendered).not_to have_link(t('account.index.email_add'))
      end
    end

    context 'after an invalid selection' do
      before { flash[:error] = t('email_address.not_found') }

      it 'renders the error in the card' do
        expect(rendered).to have_css(
          '.auth--form-page .usa-alert--error',
          text: t('email_address.not_found'),
        )
      end
    end
  end
end
