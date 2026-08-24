require 'rails_helper'

RSpec.describe NDS::CardComponent, type: :component do
  it 'renders a plain div.card by default (non-interactive)' do
    rendered = render_inline(NDS::CardComponent.new) { 'Body' }
    expect(rendered).to have_css('div.card > .card__inner > .card__body', text: 'Body')
    expect(rendered).not_to have_css('.card--interactive')
    expect(rendered).not_to have_css('.card--compact')
  end

  it 'adds --compact for padding: :compact' do
    rendered = render_inline(NDS::CardComponent.new(padding: :compact)) { 'x' }
    expect(rendered).to have_css('div.card.card--compact')
  end

  it 'renders an interactive link card when url is given' do
    rendered = render_inline(NDS::CardComponent.new(url: '/somewhere')) { 'Go' }
    expect(rendered).to have_css('a.card.card--interactive[href="/somewhere"]', text: 'Go')
  end

  it 'renders a button card when button: true' do
    rendered = render_inline(NDS::CardComponent.new(button: true)) { 'Press' }
    expect(rendered).to have_css('button.card.card--interactive[type="button"]', text: 'Press')
  end

  it 'renders a button_to (card-form) when url + non-get method' do
    rendered = render_inline(NDS::CardComponent.new(url: '/act', method: :post)) { 'Act' }
    expect(rendered).to have_css('form.card-form')
    expect(rendered).to have_css('form.card-form button.card.card--interactive', text: 'Act')
  end

  it 'renders the trailing slot' do
    rendered = render_inline(NDS::CardComponent.new) do |c|
      c.with_trailing { 'TRAIL' }
      'Body'
    end
    expect(rendered).to have_css('.card__inner > .card__trailing', text: 'TRAIL')
    expect(rendered).to have_css('.card__inner > .card__body', text: 'Body')
  end

  it 'passes through custom classes (e.g. --mfa)' do
    rendered = render_inline(NDS::CardComponent.new(class: 'card--mfa')) { 'x' }
    expect(rendered).to have_css('div.card.card--mfa')
  end

  it 'validates button cannot combine with url' do
    expect { render_inline(NDS::CardComponent.new(button: true, url: '/x')) { 'x' } }
      .to raise_error(ActiveModel::ValidationError)
  end

  it 'validates method requires a url' do
    expect { render_inline(NDS::CardComponent.new(method: :post)) { 'x' } }
      .to raise_error(ActiveModel::ValidationError)
  end

  it 'emits the card classes' do
    rendered = render_inline(NDS::CardComponent.new(url: '/x', padding: :compact)) { 'x' }
    expect(rendered).to have_css('a.card.card--compact.card--interactive[href="/x"]')
  end
end
