require 'rails_helper'

RSpec.describe Idv::WelcomePresenter do
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
    expect(presenter.sp_name).to eq(sp.friendly_name)
  end

  it 'gives us the correct title' do
    expect(presenter.title).to eq(t('doc_auth.headings.welcome', sp_name: sp.friendly_name))
  end

  describe 'the explanation' do
    let(:help_link) { '<a href="https://www.example.com>Learn more about verifying your identity</a>' }

    context 'when a selfie is not required' do
      it 'uses the getting started message' do
        expect(presenter.explanation_text(help_link)).to eq(
          t(
            'doc_auth.info.getting_started_html',
            sp_name: sp.friendly_name,
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
            sp_name: sp.friendly_name,
            link_html: help_link,
          ),
        )
      end
    end
  end

  describe 'the bullet points' do
    context 'when a selfie is not required' do
      it 'uses the no selfie bullet point 1 header' do
        expect(presenter.bullet_header(1)).to eq(
          t('doc_auth.instructions.bullet1'),
        )
      end

      it 'uses the no selfie bullet point 1 text' do
        expect(presenter.bullet_text(1)).to eq(
          t('doc_auth.instructions.text1'),
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

      it 'uses the selfie bullet point 1 header' do
        expect(presenter.bullet_header(1)).to eq(
          t('doc_auth.instructions.bullet1_with_selfie'),
        )
      end

      it 'uses the selfie bullet point 1 text' do
        expect(presenter.bullet_text(1)).to eq(
          t('doc_auth.instructions.text1_with_selfie'),
        )
      end
    end

    it 'shows the bullet point 2 header' do
      expect(presenter.bullet_header(2)).to eq(
        t('doc_auth.instructions.bullet2'),
      )
    end

    it 'shows the bullet point 2 text' do
      expect(presenter.bullet_text(2)).to eq(
        t('doc_auth.instructions.text2'),
      )
    end

    it 'shows the bullet point 3 header' do
      expect(presenter.bullet_header(3)).to eq(
        t('doc_auth.instructions.bullet3'),
      )
    end

    it 'shows the bullet point 3 text' do
      expect(presenter.bullet_text(3)).to eq(
        t('doc_auth.instructions.text3'),
      )
    end

    it 'shows the bullet point 4 header' do
      expect(presenter.bullet_header(4)).to eq(
        t('doc_auth.instructions.bullet4', app_name: sp.friendly_name),
      )
    end

    it 'shows the bullet point 4 text' do
      expect(presenter.bullet_text(4)).to eq(
        t('doc_auth.instructions.text4'),
      )
    end
  end
end
