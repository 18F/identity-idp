# frozen_string_literal: true

# NDS modal. Renders the .modal structure (dialog.modal inside the shared
# lg-modal wrapper so the same JS drives it) with optional trigger/media/
# title/description/footer slots. Instantiated by ModalComponent when a render
# resolves to the NDS bucket; call sites always use ModalComponent directly.
class NDSModalComponent < ModalComponent
  attr_writer :unique_id

  def dialog_id
    tag_options[:id].presence || "modal-#{unique_id}"
  end

  def title_id
    "#{dialog_id}-title"
  end

  def nds_description_id
    "#{dialog_id}-description"
  end

  def nds_css_class
    ['modal', ('modal--wide' if wide), *tag_options[:class]].compact
  end

  def body_css_class
    ['modal__body', ('modal__body--media' if media?)].compact
  end

  def nds_dialog_aria
    {
      # Fall back to the legacy label_id/description_id so block-content sites
      # (which set those ids on their own heading/description) stay labelled and
      # described without title/description slots, matching legacy a11y.
      labelledby: (title? ? title_id : label_id),
      describedby: (description? ? nds_description_id : description_id),
    }.compact
  end

  def nds_dialog_data
    tag_options[:data].to_h.merge(
      nds_modal: true,
      nds_modal_dismissible: dismissible,
    )
  end
end
