require 'rails_helper'

RSpec.describe ModalComponent, type: :component do
  it 'associates the trigger and dialog with accessible labels' do
    rendered = render_inline(described_class.new) do |c|
      c.with_trigger { 'Open modal' }
      c.with_title { 'Modal title' }
      c.with_description { 'Modal description' }
    end

    dialog = rendered.css('dialog').first

    expect(rendered).to have_css(
      "button[aria-controls='#{dialog['id']}'][aria-haspopup=dialog]",
    )
    expect(rendered.at_css("##{dialog['aria-labelledby']}").text.strip).to eq('Modal title')
    expect(rendered.at_css("##{dialog['aria-describedby']}").text.strip).to eq('Modal description')
  end

  it 'requires a title' do
    expect do
      render_inline(described_class.new)
    end.to raise_error(ActiveModel::ValidationError, /Title/)
  end

  context 'with the wide variant and a media slot' do
    let(:rendered) do
      render_inline(described_class.new(wide: true)) do |c|
        c.with_media { '<img alt="" aria-hidden="true" src="/seal.png">'.html_safe }
        c.with_title { 'Your account is ready' }
        c.with_description { 'Body copy' }
        c.with_footer { '<button type="button">Start exploring</button>'.html_safe }
      end
    end

    it 'flags the dialog as wide' do
      expect(rendered).to have_css('dialog.ads-modal.ads-modal--wide', visible: :all)
    end

    it 'renders the media above a padded inner body' do
      expect(rendered).to have_css('.ads-modal__body.ads-modal__body--media', visible: :all)
      expect(rendered).to have_css(
        '.ads-modal__body--media > .ads-modal__media img[aria-hidden=true]',
        visible: :all,
      )
      expect(rendered).to have_css(
        '.ads-modal__body--media > .ads-modal__body-inner .ads-modal__title',
        visible: :all,
      )
    end

    it 'keeps the title as an h2' do
      expect(rendered).to have_css(
        'h2.ads-modal__title', text: 'Your account is ready', visible: :all
      )
    end
  end

  it 'omits the media wrapper for the default variant' do
    rendered = render_inline(described_class.new) do |c|
      c.with_title { 'Modal title' }
    end

    expect(rendered).to_not have_css('.ads-modal__media', visible: :all)
    expect(rendered).to_not have_css('.ads-modal__body-inner', visible: :all)
    expect(rendered).to have_css('.ads-modal__body > .ads-modal__heading', visible: :all)
  end

  it 'always renders a close control' do
    rendered = render_inline(described_class.new(dismissible: false)) do |c|
      c.with_title { 'Modal title' }
    end

    expect(rendered).to have_css(
      'button.ads-modal__close[data-ads-modal-close]',
      visible: :all,
    )
  end
end
