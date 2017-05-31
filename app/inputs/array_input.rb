class ArrayInput < SimpleForm::Inputs::StringInput
  # simple_form throws a deprecation warning noting that the
  # method signature should be changed to add this parameter
  def input(_wrapper_options)
    input_html_options[:type] ||= input_type

    existing_values = Array(object.public_send(attribute_name)).map do
      build
    end

    existing_values.push(build) if existing_values.empty?

    safe_join(existing_values)
  end

  def input_type
    :text
  end

  def build
    options = {
      value: nil,
      class: 'block col-12 field',
      autocomplete: 'off',
      name: "#{object_name}[#{attribute_name}][]",
    }

    builder.text_field(nil, input_html_options.merge(options))
  end

  def builder
    @builder ||= :builder
  end
end
