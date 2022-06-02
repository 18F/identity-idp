require 'rails_helper'

RSpec.describe JavascriptRequiredComponent, type: :component do
  include Rails.application.routes.url_helpers

  let(:header) { 'You must enable JavaScript' }
  let(:intro) { nil }
  let(:content) { 'JavaScript-required content' }

  subject(:rendered) do
    render_inline described_class.new(header: header, intro: intro).with_content(content)
  end

  it 'renders instructions to enable JavaScript' do
    first_resource = described_class::BROWSER_RESOURCES.first

    expect(rendered).to have_css('noscript h1', text: header)
    expect(rendered).to have_css('noscript p', count: 2)
    expect(rendered).to have_link(first_resource[:name], href: first_resource[:url])
  end

  it 'renders content for JavaScript-enabled environments' do
    expect(rendered).to have_css('.js', text: content)
    expect(rendered).not_to have_content(t('components.javascript_required.enabled_alert'))
  end

  it 'loads css resource for setting session key in JavaScript-disabled environments' do
    expect(rendered).to have_css('noscript link') do |node|
      node[:href] == no_js_detect_css_path
    end
  end

  context 'with intro' do
    let(:intro) { 'To complete this process, you must enable JavaScript' }

    it 'renders instructions to enable JavaScript' do
      expect(rendered).to have_css('noscript p', text: intro)
      expect(rendered).to have_css('noscript p', count: 3)
    end
  end

  context 'with session which was previously no-js' do
    before do
      controller.session[NoJsController::SESSION_KEY] = true
    end

    it 'renders alert confirming successful enabling of JS' do
      expect(rendered).to have_content(t('components.javascript_required.enabled_alert'))
    end

    it 'only renders the alert once' do
      rendered

      second_rendered = render_inline described_class.new(header: header)

      expect(second_rendered).not_to have_content(t('components.javascript_required.enabled_alert'))
    end
  end
end
