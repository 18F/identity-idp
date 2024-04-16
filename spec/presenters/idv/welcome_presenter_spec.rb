require 'rails_helper'

RSpec.describe Idv::WelcomePresenter do
  subject(:presenter) { Idv::WelcomePresenter.new(decorated_sp_session) }

  let(:sp) { build(:service_provider) }

  let(:sp_session) { {} }

  let(:view_context) { ActionController::Base.new.view_context }

  let(:decorated_sp_session) do
    ServiceProviderSession.new(
      sp: sp,
      view_context: view_context,
      sp_session: sp_session,
      service_provider_request: nil,
    )
  end

  let(:user) { build(:user) }

  before do
    allow(view_context).to receive(:current_user).and_return(user)
  end

  it 'gives us the correct sp_name' do
    expect(presenter.sp_name).to eq(sp.friendly_name)
  end

  it 'gives us the correct title' do
    expect(presenter.title).to eq(t('doc_auth.headings.welcome', sp_name: sp.friendly_name))
  end

  describe 'the explanation' do
    let(:help_link) { '<a href="https://www.example.com>Learn more about verifying your identity</a>' }

    context 'for first-time users' do
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

    context 'as part of a step-up for an existing verified user' do
      let(:user) { build(:user, :proofed) }

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
    it 'uses the bullet point 1 header' do
      expect(presenter.bullet_points[0].bullet).to eq(
        t('doc_auth.instructions.bullet1'),
      )
    end

    it 'uses the bullet point 1 text' do
      expect(presenter.bullet_points[0].text).to eq(
        t('doc_auth.instructions.text1'),
      )
    end

    it 'uses the bullet point 2 header' do
      expect(presenter.bullet_points[1].bullet).to eq(
        t('doc_auth.instructions.bullet2'),
      )
    end

    it 'uses the bullet point 2 text' do
      expect(presenter.bullet_points[1].text).to eq(
        t('doc_auth.instructions.text2'),
      )
    end

    it 'uses the bullet point 3 header' do
      expect(presenter.bullet_points[2].bullet).to eq(
        t('doc_auth.instructions.bullet3'),
      )
    end

    it 'uses the bullet point 3 text' do
      expect(presenter.bullet_points[2].text).to eq(
        t('doc_auth.instructions.text3'),
      )
    end

    it 'uses the bullet point 4 header' do
      expect(presenter.bullet_points[3].bullet).to eq(
        t('doc_auth.instructions.bullet4', app_name: APP_NAME),
      )
    end

    it 'uses the bullet point 4 text' do
      expect(presenter.bullet_points[3].text).to eq(
        t('doc_auth.instructions.text4'),
      )
    end
  end
end
