require 'rails_helper'

RSpec.describe FlashComponent, type: :component do
  let(:flash) { {} }

  subject(:rendered) { render_inline FlashComponent.new(flash:) }

  context 'flash key, but not message, is present' do
    let(:flash) { { 'error' => '' } }

    it 'renders nothing' do
      expect(rendered).not_to have_selector('div[role="alert"]')
    end
  end

  context 'key and value are present' do
    let(:flash) { { 'error' => 'an error' } }

    it 'renders a flash message' do
      expect(rendered).to have_selector('div[role="alert"]')
    end
  end

  context 'alert flash type' do
    let(:flash) { { 'alert' => 'an error' } }

    it 'renders normalized flash keys' do
      expect(rendered).to have_selector('div[role="alert"]')
    end
  end

  context 'success flash type' do
    let(:flash) { { 'success' => 'You have confirmed your email address' } }

    it 'renders a toast instead of an alert' do
      expect(rendered).to have_css(
        'lg-toast.ads-toast',
        text: 'You have confirmed your email address',
      )
      expect(rendered).not_to have_css('.ads-alert')
    end
  end

  context 'unknown flash keys' do
    let(:flash) { { 'nonsense' => 'an error' } }

    it 'renders nothing' do
      expect(rendered).not_to have_selector('div[role="alert"]')
    end
  end
end
