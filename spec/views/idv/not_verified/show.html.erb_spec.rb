require 'rails_helper'

RSpec.describe 'idv/not_verified/show.html.erb' do
  let(:sp_name) { nil }
  let(:nds_layout) { false }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    allow(view).to receive(:decorated_sp_session).and_return(
      instance_double(ServiceProviderSession, sp_name: sp_name),
    )

    render
  end

  context 'without an sp' do
    it 'renders the fail link text with application name' do
      expect(rendered).to have_text(
        strip_tags(
          t(
            'idv.failure.verify.fail_link_html',
            sp_name: APP_NAME,
          ),
        ),
      )
    end
  end

  context 'with an sp' do
    let(:sp_name) { 'Department of Departments' }
    it 'renders the fail link text with the SP name' do
      expect(rendered).to have_text(
        strip_tags(
          t('idv.failure.verify.fail_link_html', sp_name: sp_name),
        ),
      )
    end
  end

  describe('exit button') do
    it 'is rendered' do
      expect(rendered).to have_selector(
        'a',
        text: t('idv.failure.verify.exit', app_name: APP_NAME),
      )
    end
    it 'links to the right place' do
      expect(rendered).to have_link(
        t('idv.failure.verify.exit', app_name: APP_NAME),
        href: return_to_sp_failure_to_proof_path,
      )
    end
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'renders the exit primary action and a get-help secondary action to the account page' do
      expect(rendered).to have_css(
        '.auth__actions a.usa-button:not(.usa-button--secondary)',
        text: t('idv.failure.verify.exit', app_name: APP_NAME),
      )
      expect(rendered).to have_css(
        ".auth__actions a.usa-button--secondary[href='#{account_path}']",
        text: strip_tags(t('idv.failure.verify.fail_link_html', sp_name: APP_NAME)),
      )
    end

    it 'keeps the help sentence in the body without an inline link' do
      expect(rendered).to have_css(
        '.auth__form-page-body p',
        text: t('idv.failure.verify.fail_text'),
      )
      expect(rendered).not_to have_css('.auth__form-page-body a')
    end

    context 'with an sp' do
      let(:sp_name) { 'Department of Departments' }

      it 'points the get-help action at the SP failure-to-proof redirect' do
        expect(rendered).to have_css(
          '.auth__actions a.usa-button--secondary',
          text: strip_tags(t('idv.failure.verify.fail_link_html', sp_name: sp_name)),
        )
        expect(rendered).to have_link(
          strip_tags(t('idv.failure.verify.fail_link_html', sp_name: sp_name)),
          href: return_to_sp_failure_to_proof_path(step: 'verify_info', location: 'show'),
        )
      end
    end
  end
end
