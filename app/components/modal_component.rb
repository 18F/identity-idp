class ModalComponent < BaseComponent
  attr_reader :tag_options

  def initialize(**tag_options)
    @tag_options = tag_options
  end

  def css_class
    ['usa-modal-wrapper', *tag_options[:class]]
  end

  def label_id
    "modal-label-#{unique_id}"
  end

  def description_id
    "modal-description-#{unique_id}"
  end

  def dismiss_button(**button_options, &block)
    render(
      ButtonComponent.new(
        **button_options,
        data: button_options[:data].to_h.merge(dismiss: ''),
      ),
      &block
    )
  end
end
