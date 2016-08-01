module ApplicationHelper
  def title(title)
    content_for(:title) { title }
  end

  def card_cls(cls)
    content_for(:card_cls) { cls }
  end

  def tooltip(text)
    content_tag(
      :div, \
      image_tag(asset_url('tooltip.svg'), width: 12, class: 'img-tooltip'), \
      class: 'hint--top', \
      'aria-label': text
    )
  end

  def required_form_field(*args, &block)
    content_tag(:p, "* #{t('forms.required_field')}", class: 'italic') +
      simple_form_for(*args, &block)
  end
end
