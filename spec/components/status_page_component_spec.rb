require 'rails_helper'

RSpec.describe StatusPageComponent, type: :component do
  include ActionView::Helpers::TagHelper

  it 'renders default icon associated with status' do
    rendered = render_inline(StatusPageComponent.new(status: :warning)) { |c| c.with_header { '' } }

    expect(rendered).to have_css(
      "img[alt='#{t('image_description.warning')}'][src*='warning']",
    )
  end

  it 'renders icon associated with status' do
    rendered = render_inline(StatusPageComponent.new(status: :error, icon: :lock)) do |c|
      c.with_header { '' }
    end

    expect(rendered).to have_css(
      "img[alt='#{t('image_description.error_lock')}'][src*='error-lock']",
    )
  end

  it 'renders page heading' do
    rendered = render_inline(StatusPageComponent.new) { |c| c.with_header { 'Heading' } }

    expect(rendered).to have_css('h1', text: 'Heading')
  end

  it 'renders block content' do
    rendered = render_inline(StatusPageComponent.new) do |c|
      c.with_header { 'Heading' }
      content_tag(:p, 'Content')
    end

    expect(rendered).to have_css('h1 + p', text: 'Content')
  end

  it 'renders action buttons' do
    rendered = render_inline(StatusPageComponent.new) do |c|
      c.with_action_button(outline: true) { 'Cancel' }
    end

    expect(rendered).to have_css(
      '.usa-button.usa-button--big.usa-button--wide.usa-button--outline',
      text: 'Cancel',
    )
  end

  it 'renders troubleshooting options' do
    rendered = render_inline(StatusPageComponent.new) do |c|
      c.with_troubleshooting_options do |tc|
        tc.with_header { 'Troubleshooting' }
        tc.with_option(url: '/', new_tab: true) { 'Option' }
      end
    end

    expect(rendered).to have_content('Troubleshooting')
    expect(rendered).to have_link('Option', href: '/')
  end

  it 'does not render page footer' do
    rendered = render_inline(StatusPageComponent.new)

    expect(rendered).not_to have_css('.page-footer')
  end

  it 'validates status' do
    expect do
      render_inline StatusPageComponent.new(status: :foo)
    end.to raise_error(ActiveModel::ValidationError)
  end

  it 'validates status icon' do
    expect do
      render_inline StatusPageComponent.new(status: :warning, icon: :foo)
    end.to raise_error(ActiveModel::ValidationError)
  end

  it 'validates missing default icon associated with status' do
    expect do
      render_inline StatusPageComponent.new(status: :info)
    end.to raise_error(ActiveModel::ValidationError)
  end

  context 'with footer' do
    it 'renders page footer' do
      rendered = render_inline(StatusPageComponent.new) do |c|
        c.with_footer.with_content('Footer')
      end

      expect(rendered).to have_css('.page-footer', text: 'Footer')
    end
  end
end
