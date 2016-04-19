module ApplicationHelper
  def title(title)
    content_for(:title) { title }
  end

  def required_form_field(*args, &block)
    content_tag(:p, "* #{t('upaya.forms.required_field')}", class: 'disclaimer-basic required') +
      simple_form_for(*args, &block)
  end
end
