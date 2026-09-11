class ModalComponentPreview < BaseComponentPreview
  include ActionView::Context
  include ActionView::Helpers::TagHelper

  # ModalComponent renders the default modal by default. Add ?ui_test_bucket=nds
  # to the preview URL to load the NDS layout and see the NDS `.modal` structure
  # (`dialog.modal` with the close button, heading, and action slots); without
  # it the preview shows the default `lg-modal > dialog.modal__content` markup.

  # @!group Preview
  def default
    render(ModalComponent.new) do |c|
      heading_and_body(c)
    end
  end

  def non_dismissible
    render(ModalComponent.new(dismissible: false)) do |c|
      heading_and_body(c)
    end
  end

  def wide
    render(ModalComponent.new(wide: true)) do |c|
      heading_and_body(c)
    end
  end

  def with_slots
    render(ModalComponent.new) do |c|
      c.with_title { 'Modal title' }
      c.with_description { 'A short supporting description for the modal.' }
      c.with_footer { 'Footer actions go here' }
      'Modal body content.'
    end
  end

  def with_media
    render(ModalComponent.new) do |c|
      c.with_media { 'Media area' }
      c.with_title { 'Modal title' }
      'Modal body content.'
    end
  end
  # @!endgroup

  # @param title text
  # @param description text
  # @param footer text
  # @param body text
  # @param dismissible toggle
  # @param wide toggle
  def workbench(
    title: 'Modal title',
    description: 'A short supporting description for the modal.',
    footer: 'Footer actions go here',
    body: 'Modal body content.',
    dismissible: true,
    wide: false
  )
    render(ModalComponent.new(dismissible:, wide:)) do |c|
      c.with_title { title } if title.present?
      c.with_description { description } if description.present?
      c.with_footer { footer } if footer.present?
      body
    end
  end

  private

  # The default modal has no title slot; its callers set label_id/description_id
  # on their own heading. This mirrors that so the preview reads sensibly in
  # both buckets.
  def heading_and_body(component)
    safe_join(
      [
        content_tag(:h2, 'Modal title', id: component.label_id),
        content_tag(:p, 'Modal body content.', id: component.description_id),
      ],
    )
  end
end
