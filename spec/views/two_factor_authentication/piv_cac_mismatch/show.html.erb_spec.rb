require 'rails_helper'

RSpec.describe 'two_factor_authentication/piv_cac_mismatch/show.html.erb' do
  let(:has_other_authentication_methods) {}
  let(:piv_cac_required) {}

  subject(:rendered) { render }

  before do
    @has_other_authentication_methods = has_other_authentication_methods
    @piv_cac_required = piv_cac_required
    allow(view).to receive(:user_session).and_return({})
  end

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
        assign(:account_recovery_url, account_recovery_pending_status_url)
        assign(:account_recovery_pending, true)
      end

      it 'links to the pending request without a legacy deletion link' do
        expect(rendered).to have_link(
          t('two_factor_authentication.account_recovery.pending_link'),
          href: account_recovery_pending_status_url,
        )
        expect(rendered).not_to have_link(href: account_reset_recovery_options_url)
      end
    end
  end

  context 'when user has other authentication methods' do
    let(:has_other_authentication_methods) { true }

    it 'renders instructions with a link to authenticate' do
      expect(rendered).to have_content(t('two_factor_authentication.piv_cac_mismatch.instructions'))
      expect(rendered).to have_button(t('two_factor_authentication.piv_cac_mismatch.cta'))
    end

    context 'when piv cac is required' do
      let(:piv_cac_required) { true }

      it 'does not provide an option to skip setting up piv/cac' do
        expect(rendered).not_to have_button(t('two_factor_authentication.piv_cac_mismatch.skip'))
      end
    end

    context 'when piv cac is not required' do
      let(:piv_cac_required) { false }

      it 'provides an option to skip setting up piv/cac' do
        expect(rendered).to have_button(t('two_factor_authentication.piv_cac_mismatch.skip'))
      end
    end
  end

  # Pattern-setter proof for the additive call-site migration: these call sites
  # carry BOTH the legacy boolean args AND the new variant: intent. The bucket
  # decides which wins.
  describe 'bucket-conditional button rendering' do
    context 'legacy bucket (nds_layout? absent/false)' do
      let(:has_other_authentication_methods) { true }
      let(:piv_cac_required) { false }

      it 'renders origin/main classes and no NDS variant modifiers' do
        expect(rendered).to have_css('.usa-button.usa-button--big.usa-button--wide')
        expect(rendered).to have_css('.usa-button.usa-button--unstyled')
        expect(rendered).not_to have_css('.usa-button--quaternary')
        expect(rendered).not_to have_css('.usa-button--secondary, .usa-button--tertiary')
      end
    end

    context 'nds bucket (nds_layout? true)' do
      before { allow(view).to receive(:nds_layout?).and_return(true) }

      context 'with other authentication methods' do
        let(:has_other_authentication_methods) { true }
        let(:piv_cac_required) { false }

        it 'renders variant modifiers and drops the legacy boolean classes' do
          # cta = primary (base .usa-button, no variant modifier) + default size lg
          expect(rendered).to have_css('.usa-button.usa-button--lg')
          # skip = quaternary
          expect(rendered).to have_css('.usa-button--quaternary')
          expect(rendered).not_to have_css('.usa-button--big')
          expect(rendered).not_to have_css('.usa-button--unstyled')
          expect(rendered).not_to have_css('.usa-button--wide')
        end
      end

      context 'without other authentication methods' do
        let(:has_other_authentication_methods) { false }

        it 'renders the destructive button as .usa-button--danger' do
          expect(rendered).to have_css('.usa-button--danger')
          expect(rendered).not_to have_css('.usa-button--big')
        end
      end
    end
  end
end
