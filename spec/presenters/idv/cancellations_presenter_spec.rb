require 'rails_helper'

RSpec.describe Idv::CancellationsPresenter do
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TranslationHelper

  let(:sp_name) { nil }

  subject(:presenter) { described_class.new(sp_name: sp_name, url_options: {}) }

  describe '#exit_heading' do
    subject(:exit_heading) { presenter.exit_heading }

    it 'returns exit heading' do
      expect(exit_heading).to eq t('idv.cancel.headings.exit.without_sp')
    end

    context 'with associated sp' do
      let(:sp_name) { 'Example SP' }

      it 'returns exit heading' do
        expect(exit_heading).to eq t(
          'idv.cancel.headings.exit.with_sp',
          app_name: APP_NAME,
          sp_name: sp_name,
        )
      end
    end
  end

  describe '#exit_description' do
    subject(:exit_description) { presenter.exit_description }

    it 'returns exit description contents' do
      expect(exit_description).to eq t(
        'idv.cancel.description.exit.without_sp',
        app_name: APP_NAME,
        account_page_text: t('idv.cancel.description.account_page'),
      )
    end

    context 'with associated sp' do
      let(:sp_name) { 'Example SP' }

      it 'returns exit description contents' do
        expect(exit_description).to eq t(
          'idv.cancel.description.exit.with_sp_html',
          app_name: APP_NAME,
          sp_name: sp_name,
          account_page_link: link_to(t('idv.cancel.description.account_page'), account_path),
        )
      end
    end
  end

  describe '#exit_action_text' do
    subject(:exit_action_text) { presenter.exit_action_text }

    it 'returns exit action text' do
      expect(exit_action_text).to eq t('idv.cancel.actions.account_page')
    end

    context 'with associated sp' do
      let(:sp_name) { 'Example SP' }

      it 'returns exit action text' do
        expect(exit_action_text).to eq t('idv.cancel.actions.exit', app_name: APP_NAME)
      end
    end
  end
end
