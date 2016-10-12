require 'rails_helper'

describe 'layouts/application.html.slim' do
  include Devise::Test::ControllerHelpers

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
end
