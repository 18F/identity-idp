class SubmitButtonComponent < ButtonComponent
  def initialize(big: true, wide: true, **tag_options)
    super(big: big, wide: wide, **tag_options)
  end

  def call
    content_tag(:'lg-submit-button', super)
  end
end
