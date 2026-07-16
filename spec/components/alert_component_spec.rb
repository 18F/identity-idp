require 'rails_helper'

RSpec.describe AlertComponent, type: :component do
  it 'assigns role="alert" for error type' do
    rendered = render_inline AlertComponent.new(type: :error, message: 'Attention!')

    expect(rendered).to have_selector('[role="alert"]', text: 'Attention!')
  end

  it 'includes a dismiss control when dismissible' do
    rendered = render_inline AlertComponent.new(message: 'Closeable')

    expect(rendered).to have_button(t('doc_auth.buttons.close'))
  end

  it 'omits dismiss control when not dismissible' do
    rendered = render_inline AlertComponent.new(message: 'Pinned', dismissible: false)

    expect(rendered).to have_no_button(t('doc_auth.buttons.close'))
  end

  it 'validates type' do
    expect do
      render_inline AlertComponent.new(type: :unknown, message: 'Nope')
    end.to raise_error(ActiveModel::ValidationError)
  end

  it 'rejects an action without both a label and URL' do
    expect do
      render_inline AlertComponent.new(message: 'Body copy', action: { label: 'Continue' })
    end.to raise_error(ActiveModel::ValidationError, /Action/)
  end
end
