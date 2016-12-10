require 'rails_helper'

describe 'layouts/application.html.slim' do
  include Devise::Test::ControllerHelpers

  before do
    allow(view).to receive(:user_fully_authenticated?).and_return(true)
    allow(view.request).to receive(:original_url).and_return('http://test.host/foobar')
  end

  context 'when i18n mode enabled' do
    before do
      allow(FeatureManagement).to receive(:enable_i18n_mode?).and_return(true)
    end

    after do
      allow(FeatureManagement).to receive(:enable_i18n_mode?).and_return(false)
    end

    it 'renders _i18n_mode.html' do
      render

      expect(view).to render_template(partial: '_i18n_mode')
    end
  end

  context 'when i18n mode disabled' do
    before do
      allow(FeatureManagement).to receive(:enable_i18n_mode?).and_return(false)
    end

    it 'does not render _i18n_mode.html' do
      render

      expect(view).to_not render_template(partial: '_i18n_mode')
    end
  end

  context 'session expiration' do
    it 'renders a javascript page refresh' do
      render

      expect(view).to render_template(partial: 'session_timeout/_expire_session')
    end

    context 'with skip_session_expiration' do
      before { assign(:skip_session_expiration, true) }

      it 'does not render a javascript page refresh' do
        render

        expect(view).to_not render_template(partial: 'session_timeout/_expire_session')
      end
    end
  end
end
