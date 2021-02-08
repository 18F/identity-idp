class InlineInput < SimpleForm::Inputs::StringInput
  def input(_wrapper_options)
    input_html_classes.push('col-10 field monospace')
    template.content_tag(
      :div, builder.text_field(attribute_name, input_html_options),
      class: 'col col-12 sm-col-5 margin-bottom-6 tablet:margin-bottom-0'
    )
  end

  def input_type
    :text
  end

  def builder
    @builder ||= :builder
  end
end
