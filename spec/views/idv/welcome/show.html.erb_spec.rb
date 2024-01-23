require 'rails_helper'

RSpec.describe 'idv/welcome/show.html.erb' do
  let(:user_fully_authenticated) { true }
  let(:sp_name) { nil }
  let(:selfie_required) { false }
  let(:user) { create(:user) }

  before do
    @decorated_sp_session = instance_double(ServiceProviderSession)
    allow(@decorated_sp_session).to receive(:sp_name).and_return(sp_name)
    allow(@decorated_sp_session).to receive(:selfie_required?).and_return(selfie_required)
    @sp_name = @decorated_sp_session.sp_name || APP_NAME
    @title = t('doc_auth.headings.welcome', sp_name: @sp_name)
    allow(view).to receive(:decorated_sp_session).and_return(@decorated_sp_session)
    allow(view).to receive(:user_fully_authenticated?).and_return(user_fully_authenticated)
    allow(view).to receive(:user_signing_up?).and_return(false)
    allow(view).to receive(:url_for).and_wrap_original do |method, *args, &block|
      method.call(*args, &block)
    rescue
      ''
    end
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
      expect(rendered).to have_content(@title)
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
      let(:selfie_required) { true }

      it 'renders a modified welcome template' do
        expect(rendered).to have_content(t('doc_auth.instructions.bullet1_with_selfie'))
      end
    end
  end
end
