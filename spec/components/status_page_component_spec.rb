require 'rails_helper'

RSpec.describe StatusPageComponent, type: :component do
  include ActionView::Helpers::TagHelper

  it 'renders default icon associated with status' do
    rendered = render_inline(StatusPageComponent.new(status: :warning)) { |c| c.header { '' } }

    expect(rendered).to have_css(
      "img[alt='#{t('components.status_page.icons.warning')}'][src*='warning']",
    )
  end

  it 'renders icon associated with status' do
    rendered = render_inline(StatusPageComponent.new(status: :error, icon: :lock)) do |c|
      c.header { '' }
    end

    expect(rendered).to have_css(
      "img[alt='#{t('components.status_page.icons.lock')}'][src*='error-lock']",
    )
  end

  it 'renders page heading' do
    rendered = render_inline(StatusPageComponent.new) { |c| c.header { 'Heading' } }

    expect(rendered).to have_css('h1', text: 'Heading')
  end

  it 'renders block content' do
    rendered = render_inline(StatusPageComponent.new) do |c|
      c.header { 'Heading' }
      content_tag(:p, 'Content')
    end

    expect(rendered).to have_css('h1 + p', text: 'Content')
  end

  it 'renders action buttons' do
    rendered = render_inline(StatusPageComponent.new) do |c|
      c.action_button(outline: true) { 'Cancel' }
    end

    expect(rendered).to have_css(
      '.usa-button.usa-button--big.usa-button--wide.usa-button--outline',
      text: 'Cancel',
    )
  end

  it 'renders troubleshooting options' do
    rendered = render_inline(StatusPageComponent.new) do |c|
      c.troubleshooting_options do |tc|
        tc.header { 'Troubleshooting' }
        tc.option(url: '/', new_tab: true) { 'Option' }
      end
    end

    expect(rendered).to have_content('Troubleshooting')
    expect(rendered).to have_link('Option', href: '/')
  end

  it 'raises error for unknown status' do
    expect do
      render_inline StatusPageComponent.new(status: :foo)
    end.to raise_error(ArgumentError)
  end

  it 'raises error for unknown status icon' do
    expect do
      render_inline StatusPageComponent.new(status: :warning, icon: :foo)
    end.to raise_error(ArgumentError)
  end

  it 'raises error if no default icon associated with status' do
    expect do
      render_inline StatusPageComponent.new(status: :info)
    end.to raise_error(ArgumentError)
  end
end
