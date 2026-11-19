require 'rails_helper'

RSpec.describe 'two_factor_authentication/piv_cac_mismatch/show.html.erb' do
  let(:has_other_authentication_methods) {}
  let(:piv_cac_required) {}

  subject(:rendered) { render }

  before do
    @has_other_authentication_methods = has_other_authentication_methods
    @piv_cac_required = piv_cac_required
    allow(view).to receive(:user_session).and_return({})
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('two_factor_authentication.piv_cac_mismatch.title'))

    render
  end

  context 'in the default layout' do
    context 'when user does not have other authentication methods' do
      let(:has_other_authentication_methods) { false }

      it 'renders instructions with a link to delete their account' do
        expect(rendered).to have_content(
          t(
            'two_factor_authentication.piv_cac_mismatch.instructions_no_other_method',
            app_name: APP_NAME,
          ),
        )
        expect(rendered).to have_link(
          t('two_factor_authentication.piv_cac_mismatch.delete_account'),
          href: account_reset_recovery_options_url,
        )
      end

      context 'when account-preserving recovery is available' do
        before { assign(:account_recovery_url, account_recovery_start_url) }

        it 'offers recovery without a legacy deletion link' do
          expect(rendered).to have_link(
            t('two_factor_authentication.account_recovery.recover_link'),
            href: account_recovery_start_url,
          )
          expect(rendered).not_to have_link(href: account_reset_recovery_options_url)
          expect(rendered).to have_content(
            t('two_factor_authentication.piv_cac_mismatch.instructions_recovery'),
          )
        end
      end

      context 'with a pending recovery request' do
        before do
          assign(:account_recovery_url, nil)
          assign(:account_recovery_pending, true)
        end

        it 'offers neither a new recovery request nor legacy deletion' do
          expect(rendered).not_to have_link(href: account_recovery_start_url)
          expect(rendered).not_to have_link(href: account_reset_recovery_options_url)
          expect(rendered).not_to have_content(
            t(
              'two_factor_authentication.piv_cac_mismatch.instructions_no_other_method',
              app_name: APP_NAME,
            ),
          )
        end
      end
    end

    context 'when user has other authentication methods' do
      let(:has_other_authentication_methods) { true }

      it 'renders instructions with a link to authenticate' do
        expect(rendered).to have_content(
          t('two_factor_authentication.piv_cac_mismatch.instructions'),
        )
        expect(rendered).to have_button(t('two_factor_authentication.piv_cac_mismatch.cta'))
      end

      context 'when piv cac is required' do
        let(:piv_cac_required) { true }

        it 'does not provide an option to skip setting up piv/cac' do
          expect(rendered).not_to have_button(
            t('two_factor_authentication.piv_cac_mismatch.skip'),
          )
        end
      end

      context 'when piv cac is not required' do
        let(:piv_cac_required) { false }

        it 'provides an option to skip setting up piv/cac' do
          expect(rendered).to have_button(t('two_factor_authentication.piv_cac_mismatch.skip'))
        end
      end

      it 'renders origin/main classes and no NDS variant modifiers' do
        expect(rendered).to have_css('.usa-button.usa-button--big.usa-button--wide')
        expect(rendered).to have_css('.usa-button.usa-button--unstyled')
        expect(rendered).not_to have_css('.usa-button--quaternary')
        expect(rendered).not_to have_css('.usa-button--secondary, .usa-button--tertiary')
      end
    end

    it 'renders the cancel link' do
      expect(rendered).to have_link(t('links.cancel'), href: sign_out_url)
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the error icon and heading' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.nds-status-icon.nds-status-icon--error')
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('two_factor_authentication.piv_cac_mismatch.title'),
      )
      expect(rendered).to have_css('h1', count: 1)
    end

    it 'provides a cancel button that signs the user out' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button.usa-button--tertiary[href='#{sign_out_url}']",
        text: t('links.cancel'),
      )
    end

    context 'when user has other authentication methods' do
      let(:has_other_authentication_methods) { true }
      let(:piv_cac_required) { false }

      it 'renders the instructions' do
        expect(rendered).to have_css('.auth__form-page-body hr.divider')
        expect(rendered).to have_css(
          '.auth__form-page-body .copy--muted p',
          text: t('two_factor_authentication.piv_cac_mismatch.instructions'),
        )
      end

      it 'posts the authenticate-and-add choice as the primary action' do
        form = "form[action='#{login_two_factor_piv_cac_mismatch_url}']"

        expect(rendered).to have_css(
          "#{form} input[name=add_piv_cac_after_2fa][value=true]",
          visible: :all,
        )
        expect(rendered).to have_css(
          "#{form} button.usa-button:not(.usa-button--tertiary)",
          text: t('two_factor_authentication.piv_cac_mismatch.cta'),
        )
      end

      it 'posts the skip choice as a tertiary action without the add param' do
        skip_form = page_forms.find do |form|
          form.text.include?(t('two_factor_authentication.piv_cac_mismatch.skip'))
        end

        expect(skip_form['action']).to eq(login_two_factor_piv_cac_mismatch_url)
        expect(skip_form['method']).to eq('post')
        expect(skip_form).to have_css('button.usa-button--tertiary')
        expect(skip_form).not_to have_css('input[name=add_piv_cac_after_2fa]', visible: :all)
      end

      context 'when piv cac is required' do
        let(:piv_cac_required) { true }

        it 'does not provide an option to skip setting up piv/cac' do
          expect(rendered).not_to have_button(
            t('two_factor_authentication.piv_cac_mismatch.skip'),
          )
          expect(rendered).to have_button(t('two_factor_authentication.piv_cac_mismatch.cta'))
        end
      end
    end

    context 'when user does not have other authentication methods' do
      let(:has_other_authentication_methods) { false }

      it 'renders the instructions and a destructive delete account button' do
        expect(rendered).to have_css(
          '.auth__form-page-body .copy--muted p',
          text: t(
            'two_factor_authentication.piv_cac_mismatch.instructions_no_other_method',
            app_name: APP_NAME,
          ),
        )
        expect(rendered).to have_css(
          ".auth__actions a.usa-button.usa-button--danger" \
          "[href='#{account_reset_recovery_options_url}']",
          text: t('two_factor_authentication.piv_cac_mismatch.delete_account'),
        )
      end

      context 'when account-preserving recovery is available' do
        before { assign(:account_recovery_url, account_recovery_start_url) }

        it 'offers recovery without a legacy deletion link' do
          expect(rendered).to have_css(
            '.auth__form-page-body .copy--muted p',
            text: t('two_factor_authentication.piv_cac_mismatch.instructions_recovery'),
          )
          expect(rendered).to have_css(
            ".auth__actions a.usa-button[href='#{account_recovery_start_url}']",
            text: t('two_factor_authentication.account_recovery.recover_link').upcase_first,
          )
          expect(rendered).not_to have_link(href: account_reset_recovery_options_url)
        end
      end

      context 'with a pending recovery request' do
        before do
          assign(:account_recovery_url, nil)
          assign(:account_recovery_pending, true)
        end

        it 'renders only the heading and cancel button' do
          expect(rendered).not_to have_css('.auth__form-page-body')
          expect(rendered).not_to have_link(href: account_recovery_start_url)
          expect(rendered).not_to have_link(href: account_reset_recovery_options_url)
          expect(rendered).to have_link(t('links.cancel'), href: sign_out_url)
        end
      end
    end
  end

  def page_forms
    Capybara.string(rendered).all('form', visible: :all)
  end
end
