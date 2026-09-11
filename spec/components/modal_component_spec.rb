require 'rails_helper'

RSpec.describe ModalComponent, type: :component do
  include ActionView::Helpers::TagHelper

  let(:title_text) { 'The Title' }
  let(:description_text) { 'The Description' }
  let(:footer_text) { 'The Footer' }
  let(:media_text) { 'MEDIA' }
  let(:body_text) { 'Body' }
  let(:heading_text) { 'Heading' }

  it 'renders modal element' do
    rendered = render_inline ModalComponent.new

    expect(rendered).to have_css('lg-modal', visible: false)
  end

  it 'renders label and description association' do
    rendered = render_inline ModalComponent.new do |c|
      safe_join [
        content_tag(:h1, heading_text, id: c.label_id),
        content_tag(:p, description_text, id: c.description_id),
      ]
    end

    dialog = rendered.css('dialog').first
    labelledby_id = dialog['aria-labelledby']
    describedby_id = dialog['aria-describedby']
    heading_id = rendered.css('h1').first['id']
    description_id = rendered.css('p').first['id']

    expect(labelledby_id).to eq(heading_id)
    expect(describedby_id).to eq(description_id)
  end

  it 'renders with dismiss button' do
    rendered = render_inline ModalComponent.new do |c|
      c.dismiss_button(outline: true) { 'Dismiss' }
    end

    expect(rendered).to have_css(
      '.usa-button--outline[data-dismiss]',
      text: 'Dismiss',
      visible: false,
    )
  end

  context 'with tag options' do
    it 'renders modal with the tag options' do
      rendered = render_inline ModalComponent.new(class: 'example', data: { foo: 'bar' })

      expect(rendered).to have_css('lg-modal.example[data-foo="bar"]', visible: false)
    end
  end

  describe 'bucket-conditional rendering' do
    context 'in the default bucket' do
      before do
        allow_any_instance_of(ModalComponent).to receive(:nds_bucket?).and_return(false)
      end

      it 'renders the default lg-modal > dialog.modal__content block, no nds structure' do
        rendered = render_inline(ModalComponent.new(wide: true, dismissible: false)) { body_text }

        expect(rendered).to have_css('lg-modal > dialog.modal__content', visible: false)
        expect(rendered).to have_text(body_text)
        # nds params ignored in the default bucket
        expect(rendered).not_to have_css('.modal--wide')
        expect(rendered).not_to have_css('.modal__close')
        expect(rendered).not_to have_css('dialog.modal')
      end

      it 'ignores the nds slots and renders the same markup as the default modal' do
        normalize = ->(html) { html.gsub(/[0-9a-f]{8}/, 'ID') }

        default_markup = render_inline(ModalComponent.new) { body_text }.to_html

        with_slots = render_inline(ModalComponent.new(wide: true, dismissible: false)) do |c|
          c.with_title { title_text }
          c.with_footer { footer_text }
          body_text
        end.to_html

        expect(normalize.call(with_slots)).to eq(normalize.call(default_markup))
        expect(with_slots).not_to include('modal__title')
        expect(with_slots).not_to include('modal__actions')
      end
    end

    context 'in the nds bucket' do
      before do
        allow_any_instance_of(ModalComponent).to receive(:nds_bucket?).and_return(true)
      end

      it 'renders lg-modal > dialog.modal with a close button by default' do
        rendered = render_inline(ModalComponent.new) { body_text }

        expect(rendered).to have_css('lg-modal > dialog.modal[data-nds-modal]', visible: false)
        expect(rendered).to have_css(
          'dialog.modal > button.modal__close[data-nds-modal-close]',
          visible: false,
        )
        expect(rendered).to have_css(
          '.modal__body .modal__content', text: body_text, visible: false
        )
      end

      it 'renders the modal structure classes' do
        rendered = render_inline(ModalComponent.new(wide: true)) do |c|
          c.with_title { title_text }
          body_text
        end
        expect(rendered).to have_css('dialog.modal.modal--wide', visible: false)
        expect(rendered).to have_css('.modal__body', visible: false)
        expect(rendered).to have_css('.modal__title', visible: false)
        expect(rendered).to have_css('.modal__content', visible: false)
      end

      context 'when dismissible: false' do
        it 'omits the close button' do
          rendered = render_inline(ModalComponent.new(dismissible: false)) { body_text }
          expect(rendered).not_to have_css('.modal__close')
          expect(rendered).to have_css(
            'dialog.modal[data-nds-modal-dismissible="false"]',
            visible: false,
          )
        end
      end

      context 'when wide: true' do
        it 'adds the --wide modifier' do
          rendered = render_inline(ModalComponent.new(wide: true)) { body_text }
          expect(rendered).to have_css('dialog.modal.modal--wide', visible: false)
        end
      end

      context 'without slots' do
        it 'falls back to label_id/description_id for block-content sites' do
          # The 2 existing call sites use block content + c.label_id/c.description_id
          # (no title/description slots); parity with the default modal aria wiring.
          rendered = render_inline(ModalComponent.new) do |c|
            safe_join [
              content_tag(:h2, heading_text, id: c.label_id),
              content_tag(:p, description_text, id: c.description_id),
            ]
          end
          dialog = rendered.css('dialog').first
          heading_id = rendered.css('h2').first['id']
          description_id = rendered.css('p').first['id']
          expect(dialog['aria-labelledby']).to eq(heading_id)
          expect(dialog['aria-describedby']).to eq(description_id)
          expect(rendered).not_to have_css('.modal__title')
        end
      end

      describe 'slots' do
        it 'renders title/description/footer slots into the nds structure' do
          rendered = render_inline(ModalComponent.new) do |c|
            c.with_title { title_text }
            c.with_description { description_text }
            c.with_footer { footer_text }
            body_text
          end

          expect(rendered).to have_css(
            '.modal__heading > h2.modal__title', text: title_text, visible: false
          )
          expect(rendered).to have_css(
            '.modal__description', text: description_text, visible: false
          )
          expect(rendered).to have_css('.modal__content', text: body_text, visible: false)
          expect(rendered).to have_css('.modal__actions', text: footer_text, visible: false)

          dialog = rendered.css('dialog').first
          title_id = rendered.css('.modal__title').first['id']
          description_id = rendered.css('.modal__description').first['id']
          expect(dialog['aria-labelledby']).to eq(title_id)
          expect(dialog['aria-describedby']).to eq(description_id)
        end

        it 'renders the media slot with the media body modifier' do
          rendered = render_inline(ModalComponent.new) do |c|
            c.with_media { media_text }
            c.with_title { title_text }
            body_text
          end
          expect(rendered).to have_css('.modal__body.modal__body--media', visible: false)
          expect(rendered).to have_css('.modal__media', text: media_text, visible: false)
          expect(rendered).to have_css('.modal__body-inner', visible: false)
        end
      end
    end
  end
end
