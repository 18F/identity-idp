require 'rails_helper'

RSpec.describe NDS::ToastComponent, type: :component do
  it 'renders lg-toast.toast with the announcement structure' do
    rendered = render_inline(NDS::ToastComponent.new(message: 'Saved'))

    expect(rendered).to have_css('lg-toast.toast[data-open="false"]', visible: :all)
    expect(rendered).to have_css(
      'lg-toast .toast__announcement[data-nds-toast-announcement]',
      visible: :all,
    )
    expect(rendered).to have_css('.toast__announcement .toast__icon .usa-icon', visible: :all)
    expect(rendered).to have_css('p.toast__text', text: 'Saved', visible: :all)
  end

  it 'renders content from a block when no message given' do
    rendered = render_inline(NDS::ToastComponent.new) { 'Blocky' }
    expect(rendered).to have_css('.toast__text', text: 'Blocky', visible: :all)
  end

  it 'defaults show-delay and dismiss-after data attributes' do
    rendered = render_inline(NDS::ToastComponent.new(message: 'x'))
    toast = rendered.css('lg-toast').first
    expect(toast['data-show-delay']).to eq('500')
    expect(toast['data-dismiss-after']).to eq('3000')
  end

  it 'accepts custom show_delay and dismiss_after' do
    rendered = render_inline(
      NDS::ToastComponent.new(message: 'x', show_delay: 0, dismiss_after: 8000),
    )
    toast = rendered.css('lg-toast').first
    expect(toast['data-show-delay']).to eq('0')
    expect(toast['data-dismiss-after']).to eq('8000')
  end

  it 'passes through custom classes and merges data' do
    rendered = render_inline(
      NDS::ToastComponent.new(message: 'x', class: 'extra', data: { foo: 'bar' }),
    )
    expect(rendered).to have_css('lg-toast.toast.extra[data-foo="bar"]', visible: :all)
  end

  it 'emits the toast class and NDS announcement data hook' do
    html = render_inline(NDS::ToastComponent.new(message: 'x')).to_html
    expect(html).to include('class="toast"')
    expect(html).to include('data-nds-toast-announcement')
  end
end
