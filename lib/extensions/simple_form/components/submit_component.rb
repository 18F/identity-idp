module SubmitComponent
  def submit(*args, &block)
    options = args.extract_options!
    content, = args
    content = template.capture { yield(content) } if block
    template.render SubmitButtonComponent.new(**options, &block).with_content(content)
  end
end

SimpleForm::FormBuilder.send :include, SubmitComponent
