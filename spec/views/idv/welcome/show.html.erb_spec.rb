require 'rails_helper'

RSpec.describe 'idv/welcome/show.html.erb' do
  let(:flow_session) { {} }
  let(:user_fully_authenticated) { true }
  let(:sp_name) { nil }
  let(:user) { create(:user) }

  before do
    @decorated_session = instance_double(ServiceProviderSession)
    allow(@decorated_session).to receive(:sp_name).and_return(sp_name)
    allow(view).to receive(:decorated_session).and_return(@decorated_session)
    allow(view).to receive(:flow_session).and_return(flow_session)
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
  end

  context 'without service provider' do
    it 'renders troubleshooting options' do
      render

      expect(rendered).to have_link(t('idv.troubleshooting.options.supported_documents'))
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.learn_more_address_verification_options'),
      )
      expect(rendered).not_to have_link(
        nil,
        href: return_to_sp_failure_to_proof_url(step: 'welcome', location: 'missing_items'),
      )
    end
  end

  context 'with service provider' do
    let(:sp_name) { 'Example App' }

    it 'renders troubleshooting options' do
      render

      expect(rendered).to have_link(t('idv.troubleshooting.options.supported_documents'))
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.learn_more_address_verification_options'),
      )
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name),
        href: return_to_sp_failure_to_proof_url(step: 'welcome', location: 'missing_items'),
      )
    end
  end

  it 'renders a link to the privacy & security page' do
    render
    expect(rendered).to have_link(
      t('doc_auth.instructions.learn_more'),
      href: policy_redirect_url(flow: :idv, step: :welcome, location: :footer),
    )
  end

  context 'A/B test specifies welcome_new template' do
    before do
      @ab_test_bucket = :welcome_new
      @sp_name = 'Login.gov'
      @title = t('doc_auth.headings.getting_started', sp_name: @sp_name)
    end

    it 'renders the welcome_new template' do
      render

      expect(rendered).to have_content(@title)
      expect(rendered).to have_content(t('doc_auth.getting_started.instructions.getting_started'))
      expect(rendered).to have_link(
        t('doc_auth.info.getting_started_learn_more'),
        href: help_center_redirect_path(
          category: 'verify-your-identity',
          article: 'how-to-verify-your-identity',
          flow: :idv,
          step: :welcome_new,
          location: 'intro_paragraph',
        ),
      )
      expect(rendered).not_to have_link(
        t('doc_auth.instructions.learn_more'),
        href: policy_redirect_url(flow: :idv, step: :welcome, location: :footer),
      )
    end
  end

  context 'A/B test specifies welcome_default template' do
    before do
      @ab_test_bucket = :welcome_default
    end

    it 'renders the welcome_default template' do
      render

      expect(rendered).to have_content(t('doc_auth.headings.welcome'))
      expect(rendered).to have_content(t('doc_auth.instructions.welcome'))
      expect(rendered).to have_link(
        t('doc_auth.instructions.learn_more'),
        href: policy_redirect_url(flow: :idv, step: :welcome, location: :footer),
      )
    end
  end

  context 'A/B test unspecified' do
    before do
      @ab_test_bucket = nil
    end
    it 'renders the welcome_default template' do
      render

      expect(rendered).to have_content(t('doc_auth.headings.welcome'))
      expect(rendered).to have_content(t('doc_auth.instructions.welcome'))
      expect(rendered).to have_link(
        t('doc_auth.instructions.learn_more'),
        href: policy_redirect_url(flow: :idv, step: :welcome, location: :footer),
      )
    end
  end
end
