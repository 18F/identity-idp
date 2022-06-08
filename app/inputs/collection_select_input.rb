class CollectionSelectInput < SimpleForm::Inputs::CollectionSelectInput
  def input_html_classes
    super.push('usa-select')
  end
end
