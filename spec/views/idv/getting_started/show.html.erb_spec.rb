require 'rails_helper'

RSpec.describe 'idv/getting_started/show' do
  let(:user_fully_authenticated) { true }
  let(:sp_name) { nil }
  let(:user) { create(:user) }

  before do
    @decorated_session = instance_double(ServiceProviderSessionDecorator)
    @sp_name = 'Login.gov'
    @title = t('doc_auth.headings.getting_started', sp_name: @sp_name)
    allow(@decorated_session).to receive(:sp_name).and_return(sp_name)
    allow(view).to receive(:decorated_session).and_return(@decorated_session)
    allow(view).to receive(:user_fully_authenticated?).and_return(user_fully_authenticated)
    allow(view).to receive(:user_signing_up?).and_return(false)
    allow(view).to receive(:url_for).and_wrap_original do |method, *args, &block|
      method.call(*args, &block)
    rescue
      ''
    end
    render
  end

  context 'in doc auth with an authenticated user' do
    before do
      assign(:current_user, user)

      render
    end

    it 'renders a link to return to the SP' do
      expect(rendered).to have_link(t('links.cancel'))
    end
  end

  it 'includes code to track clicks on the consent checkbox' do
    selector = [
      'lg-click-observer[event-name="IdV: consent checkbox toggled"]',
      '[name="doc_auth[ial2_consent_given]"]',
    ].join ' '

    expect(rendered).to have_css(selector)
  end

  it 'renders a link to help center article' do
    expect(rendered).to have_link(
      t('doc_auth.info.getting_started_learn_more'),
      href: help_center_redirect_path(
        category: 'verify-your-identity',
        article: 'how-to-verify-your-identity',
        flow: :idv,
        step: :getting_started,
        location: 'intro_paragraph',
      ),
    )
  end

  it 'renders a link to the privacy & security page' do
    expect(rendered).to have_link(
      t('doc_auth.getting_started.instructions.learn_more'),
      href: policy_redirect_url(flow: :idv, step: :getting_started, location: :consent),
    )
  end
end
