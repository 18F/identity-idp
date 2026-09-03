require 'rails_helper'

RSpec.describe 'users/piv_cac_authentication_setup/new.html.erb' do
  let(:user) { create(:user) }
  let(:user_session) { {} }
  let(:in_multi_mfa_selection_flow) { false }

  subject(:rendered) { render }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:user_session).and_return(user_session)
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:in_multi_mfa_selection_flow?).and_return(in_multi_mfa_selection_flow)
    form = UserPivCacSetupForm.new
    @presenter = PivCacAuthenticationSetupPresenter.new(user, true, form)
  end

  it 'does not show option to skip setting up piv/cac' do
    expect(rendered).not_to have_button(t('mfa.skip'))
  end

  context 'user has sufficient factors' do
    let(:user) { create(:user, :fully_registered) }

    it 'renders a link to cancel and go back to the account page' do
      expect(rendered).to have_link(t('links.cancel'), href: account_path)
    end

    context 'user is in the process of setting up multiple MFAs' do
      let(:in_multi_mfa_selection_flow) { true }

      it 'renders a link to choose a different option' do
        expect(rendered).to have_link(
          t('two_factor_authentication.choose_another_option'),
          href: authentication_methods_setup_path,
        )
      end
    end
  end

  context 'user is setting up 2FA' do
    let(:user) { create(:user) }

    it 'renders a link to choose a different option' do
      expect(rendered).to have_link(
        t('two_factor_authentication.choose_another_option'),
        href: authentication_methods_setup_path,
      )
    end
  end

  context 'when adding piv cac after 2fa' do
    let(:user_session) { { add_piv_cac_after_2fa: true } }

    it 'shows option to skip setting up piv/cac' do
      expect(rendered).to have_button(t('mfa.skip'))
    end

    it 'renders a link to cancel and sign out' do
      expect(rendered).to have_link(t('links.cancel'), href: sign_out_path)
    end

    context 'when SP requires PIV/CAC' do
      before do
        @piv_cac_required = true
      end

      it 'does not show option to skip setting up piv/cac' do
        expect(rendered).not_to have_button(t('mfa.skip'))
      end

      it 'renders a link to cancel and sign out' do
        expect(rendered).to have_link(t('links.cancel'), href: sign_out_path)
      end
    end
  end

  context 'nds bucket' do
    let(:in_account_creation_flow) { false }
    let(:enabled_mfa_methods_count) { 0 }

    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      allow(view).to receive(:in_account_creation_flow?).and_return(in_account_creation_flow)
      allow(view).to receive(:enabled_mfa_methods_count).and_return(enabled_mfa_methods_count)
    end

    it 'renders the NDS form-page card with the setup heading' do
      expect(rendered).to have_css('section.auth.auth--form-page')
      expect(rendered).to have_css('h1', text: t('titles.piv_cac_login.add'))
    end

    it 'preserves the nickname field and setup form action' do
      expect(rendered).to have_css("form[action=\"#{submit_new_piv_cac_url}\"]")
      expect(rendered).to have_css('input.usa-input#name[name="name"][maxlength="20"]')
    end

    it 'renders the nickname as an NDS floating-label input group' do
      expect(rendered).to have_css('.usa-form-group.usa-input-group--floating')
      expect(rendered).to have_css(
        'label.usa-label[for="name"]',
        text: t('nds.piv_cac_setup.nickname'),
        count: 1,
      )
    end

    it 'renders the three numbered setup steps as separate bordered cards' do
      expect(rendered).to have_css('li .card', count: 3)
      expect(rendered).to have_no_css('.usa-process-list')
      (1..3).each do |step|
        expect(rendered).to have_css(
          ".card ol.usa-list[start=\"#{step}\"] li.text-body-emphasis",
          text: t("nds.piv_cac_setup.step_#{step}"),
        )
      end
    end

    it 'gates the submit until the required nickname is valid' do
      expect(rendered).to have_css('form[data-nds-submit-gate]')
    end

    it 'nests the nickname input inside the first step card' do
      expect(rendered).to have_css(
        'li:first-child .card .usa-form-group.usa-input-group--floating input#name',
      )
    end

    it 'renders the card-reader animation inside the second step card' do
      expect(rendered).to have_css('li .card video[autoplay][loop][muted][playsinline]')
    end

    it 'renders the primary submit inside the actions region' do
      expect(rendered).to have_css(
        '.auth__actions button[type="submit"]',
        text: t('forms.buttons.continue'),
      )
    end

    context 'when not in the account-creation flow' do
      it 'does not emit the header progress stepper' do
        rendered
        expect(view.content_for(:nds_header_progress)).to be_blank
      end
    end

    context 'when adding a first method during account creation' do
      let(:in_account_creation_flow) { true }
      let(:enabled_mfa_methods_count) { 0 }

      it 'emits the Security stepper on the first substep' do
        rendered
        progress = view.content_for(:nds_header_progress)
        expect(progress).to have_css('.progress__step[aria-current="step"]', text: 'Security')
        expect(progress).to have_content('1 / 2')
      end
    end

    context 'when adding a second method during account creation' do
      let(:in_account_creation_flow) { true }
      let(:enabled_mfa_methods_count) { 1 }

      it 'emits the Security stepper on the second substep' do
        rendered
        expect(view.content_for(:nds_header_progress)).to have_content('2 / 2')
      end
    end

    context 'user is setting up 2FA' do
      it 'offers the choose-another-method link' do
        expect(rendered).to have_link(
          t('nds.mfa.choose_another_method'),
          href: authentication_methods_setup_path,
        )
      end
    end

    context 'user has sufficient factors' do
      let(:user) { create(:user, :fully_registered) }

      it 'offers a cancel link to the account page' do
        expect(rendered).to have_link(t('links.cancel'), href: account_path)
      end
    end

    context 'when adding piv cac after 2fa' do
      let(:user_session) { { add_piv_cac_after_2fa: true } }

      it 'renders the skip submit and sign-out cancel link' do
        expect(rendered).to have_css(
          'button[type="submit"][name="skip"][value="true"][formnovalidate]',
          text: t('mfa.skip'),
        )
        expect(rendered).to have_link(t('links.cancel'), href: sign_out_path)
      end
    end
  end
end
