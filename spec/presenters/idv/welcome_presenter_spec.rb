require 'rails_helper'

RSpec.describe Idv::WelcomePresenter do
  # include ActionView::Helpers::UrlHelper
  # include ActionView::Helpers::TagHelper
  # include Rails.application.routes.url_helpers
  # include LinkHelper

  subject(:presenter) { Idv::WelcomePresenter.new(decorated_sp_session) }

  let(:sp) { build(:service_provider) }

  let(:sp_session) { {} }

  let(:decorated_sp_session) do
    ServiceProviderSession.new(
      sp: sp,
      view_context: nil,
      sp_session: sp_session,
      service_provider_request: nil,
    )
  end

  it 'gives us the correct sp_name' do
    expect(presenter.sp_name).to eq('Test Service Provider')
  end

  it 'gives us the correct title' do
    expect(presenter.title).to eq(t('doc_auth.headings.welcome', sp_name: 'Test Service Provider'))
  end

  describe 'the explanation' do
    let(:help_link) { '<a href="https://www.example.com>Learn more about verifying your identity</a>' }

    context 'when a selfie is not required' do
      it 'uses the getting started message' do
        expect(presenter.explanation_text(help_link)).to eq(
          t(
            'doc_auth.info.getting_started_html',
            sp_name: 'Test Service Provider',
            link_html: help_link,
          ),
        )
      end
    end

    context 'when a selfie is required' do
      let(:sp_session) do
        { biometric_comparison_required: true }
      end

      before do
        allow(IdentityConfig.store).to receive(:doc_auth_selfie_capture_enabled).and_return(true)
      end

      it 'uses the stepping up message' do
        expect(presenter.explanation_text(help_link)).to eq(
          t(
            'doc_auth.info.stepping_up_html',
            sp_name: 'Test Service Provider',
            link_html: help_link,
          ),
        )
      end
    end
  end
end
