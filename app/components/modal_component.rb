# frozen_string_literal: true

class ModalComponent < BaseComponent
  renders_one :trigger
  renders_one :media
  renders_one :title
  renders_one :description
  renders_one :footer

  attr_reader :dismissible, :wide, :tag_options

  validate :validate_title

  def initialize(dismissible: true, wide: false, **tag_options)
    @dismissible = dismissible
    @wide = wide
    @tag_options = tag_options
  end

  def dialog_id
    tag_options[:id].presence || "modal-#{unique_id}"
  end

  def title_id
    "#{dialog_id}-title"
  end

  def description_id
    "#{dialog_id}-description"
  end

  def css_class
    ['ads-modal', ('ads-modal--wide' if wide), *tag_options[:class]].compact
  end

  def body_css_class
    ['ads-modal__body', ('ads-modal__body--media' if media?)].compact
  end

  def dialog_aria
    {
      labelledby: title_id,
      describedby: (description_id if description?),
    }.compact
  end

  def dialog_data
    tag_options[:data].to_h.merge(
      ads_modal: true,
      ads_modal_dismissible: dismissible,
    )
  end

  private

  def validate_title
    return if title?

    errors.add(:title, 'is required', type: :blank)
  end
end
