# frozen_string_literal: true

class SubmitButtonComponent < ButtonComponent
  def initialize(big: true, wide: true, **tag_options)
    super(big:, wide:, **tag_options)
  end

  def call
    content_tag(:'lg-submit-button', super)
  end
end
