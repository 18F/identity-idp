require 'rails_helper'

RSpec.describe AlertComponent, type: :component do
  it 'renders message from locals' do
    rendered = render_inline AlertComponent.new(message: 'FYI')

    expect(rendered).to have_content('FYI')
  end

  it 'renders message from block' do
    rendered = render_inline(AlertComponent.new) { 'FYI' }

    expect(rendered).to have_content('FYI')
  end

  it 'prefers message from constructor arg' do
    rendered = render_inline(AlertComponent.new(message: 'locals')) { 'block' }

    expect(rendered).to have_content('locals')
  end

  it 'defaults to type "info"' do
    rendered = render_inline AlertComponent.new(message: 'FYI')

    expect(rendered).to have_selector('.usa-alert.usa-alert--info')
  end

  it 'accepts alert type param' do
    rendered = render_inline AlertComponent.new(type: :success, message: 'Hooray!')

    expect(rendered).to have_selector('.usa-alert.usa-alert--success')
  end

  it 'defaults to <p> tag for text' do
    rendered = render_inline AlertComponent.new(type: :success, message: 'Hooray!')

    expect(rendered).to have_selector('p.usa-alert__text')
  end

  it 'accepts text_tag param' do
    rendered = render_inline AlertComponent.new(type: :success, message: 'Hooray!', text_tag: 'div')

    expect(rendered).to have_selector('div.usa-alert__text')
    expect(rendered).to_not have_selector('p.usa-alert__text')
  end

  it 'accepts custom class names' do
    rendered = render_inline AlertComponent.new(message: 'FYI', class: 'my-custom-class')

    expect(rendered).to have_selector('.usa-alert.my-custom-class')
  end

  it 'accepts arbitrary tag options' do
    rendered = render_inline AlertComponent.new(message: 'FYI', data: { foo: 'bar' })

    expect(rendered).to have_selector('.usa-alert[data-foo="bar"]')
  end

  it 'assigns role="status"' do
    rendered = render_inline AlertComponent.new(message: 'FYI')

    expect(rendered).to have_selector('.usa-alert[role="status"]')
  end

  it 'assigns role="alert" for error type' do
    rendered = render_inline AlertComponent.new(type: :error, message: 'Attention!')

    expect(rendered).to have_selector('.usa-alert[role="alert"]')
  end

  it 'raises error for unknown type' do
    expect do
      render_inline AlertComponent.new(type: 'alert', message: 'Attention!')
    end.to raise_error(ArgumentError)
  end
end
