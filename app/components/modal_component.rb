# frozen_string_literal: true

class ModalComponent < BaseComponent
  include NDSBucketResolvable

  # NDS slot API, accepted additively. The legacy bucket ignores these slots
  # and renders the same block-content markup as the default modal.
  renders_one :trigger
  renders_one :media
  renders_one :title
  renders_one :description
  renders_one :footer

  attr_reader :dismissible, :wide, :tag_options

  # dismissible:/wide: are part of the NDS look and feel; the legacy bucket
  # accepts them for API compatibility but never emits anything from them.
  def initialize(dismissible: true, wide: false, **tag_options)
    @dismissible = dismissible
    @wide = wide
    @tag_options = tag_options
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

  private

  # The NDS variant excluded from the render-time flip (see
  # NDSBucketResolvable) so it renders its own markup instead of recursing.
  def nds_variant_class
    NDSModalComponent
  end

  def nds_delegate
    delegate = NDSModalComponent.new(dismissible:, wide:, **tag_options)
    # Share this component's id so the label_id/description_id the caller set on
    # its own block content still match the delegate's aria references.
    delegate.unique_id = unique_id
    delegate
  end
end
