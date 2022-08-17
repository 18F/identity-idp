class SubmitButtonComponent < ButtonComponent
  def call
    content_tag(:'lg-submit-button', super)
  end
end
