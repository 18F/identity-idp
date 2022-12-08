module LinkHelper
  EXTERNAL_LINK_CLASS = 'usa-link--external'.freeze

  def new_window_link_to(name = nil, options = nil, html_options = {}, &block)
    html_options, options, name = options, name, capture(&block) if block

    html_options[:target] = '_blank'
    html_options[:class] = [*html_options[:class], EXTERNAL_LINK_CLASS]

    name = safe_join([name, content_tag('span', t('links.new_window'), class: 'usa-sr-only')], ' ')

    link_to(name, options, html_options)
  end

  def button_or_link_to(name = nil, options = nil, html_options = nil, &block)
    html_options, options, name = options, name, block if block
    html_options ||= {}
    method = html_options[:method] || :get
    helper_method = method == :get ? :link_to : :button_to
    html_options.delete(:method) if helper_method == :link_to
    send(helper_method, name, options, html_options, &block)
  end
end
