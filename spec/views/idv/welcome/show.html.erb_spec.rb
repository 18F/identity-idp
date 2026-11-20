require 'rails_helper'

RSpec.describe 'idv/welcome/show.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:user) { create(:user) }
  let(:sp_session) { {} }
  let(:view_context) { ActionController::Base.new.view_context }
  let(:sp) { build(:service_provider) }
  let(:nds_layout) { false }
  let(:current_sp) { nil }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    allow(view).to receive(:current_sp).and_return(current_sp)
    allow(view_context).to receive(:current_user).and_return(user)
    assign(:consent_form, Idv::ConsentForm.new(idv_consent_given: false))

    decorated_sp_session = ServiceProviderSession.new(
      sp: sp,
      view_context: view_context,
      sp_session: sp_session,
      service_provider_request: nil,
    )
    presenter = Idv::WelcomePresenter.new(decorated_sp_session:)
    assign(:presenter, presenter)
    assign(:current_user, user)
    render
  end

  context 'in doc auth with an authenticated user' do
    it 'renders a link to return to the SP' do
      expect(rendered).to have_link(t('links.cancel'))
    end

    it 'renders the welcome template' do
      expect(rendered).to have_content(
        t('doc_auth.headings.welcome', sp_name: sp.friendly_name),
      )

      expect(rendered).to have_content(
        t(
          'doc_auth.info.getting_started_html',
          sp_name: sp.friendly_name,
          link_html: '',
        ),
      )
      expect(rendered).to have_content(t('doc_auth.instructions.bullet1'))
      expect(rendered).to have_link(
        t('doc_auth.info.getting_started_learn_more'),
        href: help_center_redirect_path(
          category: 'verify-your-identity',
          article: 'overview',
          flow: :idv,
          step: :welcome,
          location: 'intro_paragraph',
        ),
      )
    end
  end

  context 'when a user has the passport option' do
    it 'renders the modified bullet point' do
      expect(rendered).to have_content(t('doc_auth.instructions.bullet1'))
    end
  end

  context 'in doc auth with a step-up user' do
    let(:user) { create(:user, :proofed) }

    it 'renders a modified welcome template' do
      expect(rendered).to have_content(t('doc_auth.info.stepping_up_html', link_html: ''))
      expect(rendered).to have_link(
        t('doc_auth.info.getting_started_learn_more'),
        href: help_center_redirect_path(
          category: 'verify-your-identity',
          article: 'overview',
          flow: :idv,
          step: :welcome,
          location: 'intro_paragraph',
        ),
      )
    end
  end

  context 'with an SP logo in the default layout' do
    let(:current_sp) { build(:service_provider, logo: 'DOS.svg') }

    it 'does not render the NDS agency seal' do
      expect(rendered).not_to have_css('.agency-seal')
    end
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'renders no agency seal without an SP logo' do
      expect(rendered).not_to have_css('.agency-seal')
    end

    context 'when the SP has a logo' do
      let(:current_sp) { build(:service_provider, logo: 'DOS.svg') }

      it 'renders the 100px agency seal above the heading' do
        seal_selector = '.auth__header--with-media img.agency-seal.agency-seal--100'
        expect(rendered).to have_css("#{seal_selector}[alt=''][src='#{current_sp.logo_url}']")
        expect(rendered).not_to have_css('.auth__media')
      end
    end

    it 'renders a tertiary cancel action instead of the no-phone help link' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button--tertiary[href='#{idv_cancel_path(step: 'welcome')}']",
        text: t('links.cancel'),
      )
      expect(rendered).not_to have_link(href: /help_center.*phone-number/)
    end
  end
end
