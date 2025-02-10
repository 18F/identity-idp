require 'rails_helper'

RSpec.describe 'idv/welcome/show.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:user) { create(:user) }
  let(:sp_session) { {} }
  let(:view_context) { ActionController::Base.new.view_context }
  let(:sp) { build(:service_provider) }

  before do
    allow(view_context).to receive(:current_user).and_return(user)

    decorated_sp_session = ServiceProviderSession.new(
      sp: sp,
      view_context: view_context,
      sp_session: sp_session,
      service_provider_request: nil,
    )
    presenter = Idv::WelcomePresenter.new(decorated_sp_session)
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
end
