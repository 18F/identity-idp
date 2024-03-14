require 'rails_helper'

RSpec.describe 'idv/welcome/show.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:selfie_required) { false }
  let(:selfie_capture_enabled) { false }
  let(:user) { create(:user) }
  let(:sp_session) { {} }

  before do
    sp = build(:service_provider)
    decorated_sp_session = ServiceProviderSession.new(
      sp: sp,
      view_context: nil,
      sp_session: sp_session,
      service_provider_request: nil,
    )
    presenter = Idv::WelcomePresenter.new(decorated_sp_session)
    assign(:presenter, presenter)

    allow(IdentityConfig.store).to receive(:doc_auth_selfie_capture_enabled).
      and_return(selfie_capture_enabled)
  end

  context 'in doc auth with an authenticated user' do
    before do
      assign(:current_user, user)
      render
    end

    it 'renders a link to return to the SP' do
      expect(rendered).to have_link(t('links.cancel'))
    end

    it 'renders the welcome template' do
      expect(rendered).to have_content(
        t('doc_auth.headings.welcome', sp_name: 'Test Service Provider'),
      )
      expect(rendered).to have_content(t('doc_auth.instructions.getting_started'))
      expect(rendered).to have_content(t('doc_auth.instructions.bullet1'))
      expect(rendered).to have_link(
        t('doc_auth.info.getting_started_learn_more'),
        href: help_center_redirect_path(
          category: 'verify-your-identity',
          article: 'how-to-verify-your-identity',
          flow: :idv,
          step: :welcome,
          location: 'intro_paragraph',
        ),
      )
    end

    context 'when the SP requests IAL2 verification' do
      let(:sp_session) do
        { biometric_comparison_required: true }
      end

      let(:selfie_capture_enabled) { true }

      it 'renders a modified welcome template' do
        expect(rendered).to have_content(t('doc_auth.instructions.bullet1_with_selfie'))
      end
    end
  end
end
