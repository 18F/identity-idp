require 'rails_helper'

describe 'shared/_alert.html.erb' do
  it 'renders message from param' do
    render 'shared/alert', { message: 'FYI' }

    expect(rendered).to have_content('FYI')
  end

  it 'renders message from block' do
    render('shared/alert') { 'FYI' }

    expect(rendered).to have_content('FYI')
  end

  it 'defaults to type "info"' do
    render 'shared/alert', { message: 'FYI' }

    expect(rendered).to have_selector('.usa-alert.usa-alert--info')
  end

  it 'accepts alert type param' do
    render 'shared/alert', { type: 'success', message: 'Hooray!' }

    expect(rendered).to have_selector('.usa-alert.usa-alert--success')
  end

  it 'defaults to <p> tag for text' do
    render 'shared/alert', { type: 'success', message: 'Hooray!' }

    expect(rendered).to have_selector('p.usa-alert__text')
  end

  it 'accepts text_tag param' do
    render 'shared/alert', { type: 'success', message: 'Hooray!', text_tag: 'div' }

    expect(rendered).to have_selector('div.usa-alert__text')
    expect(rendered).to_not have_selector('p.usa-alert__text')
  end

  it 'accepts custom class names' do
    render 'shared/alert', { message: 'FYI', class: 'my-custom-class' }

    expect(rendered).to have_selector('.usa-alert.my-custom-class')
  end

  it 'assigns role="status"' do
    render 'shared/alert', { message: 'FYI' }

    expect(rendered).to have_selector('.usa-alert[role="status"]')
  end

  it 'assigns role="alert" for error type' do
    render 'shared/alert', { type: 'error', message: 'Attention!' }

    expect(rendered).to have_selector('.usa-alert[role="alert"]')
  end
end
