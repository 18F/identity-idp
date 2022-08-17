module SubmitComponent
  def submit(*args)
    options = args.extract_options!
    template.render SubmitButtonComponent.new(**options).with_content(args.first)
  end
end

SimpleForm::FormBuilder.send :include, SubmitComponent
