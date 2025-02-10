# frozen_string_literal: true

module LinkHelper
  def new_tab_link_to(name = nil, options = nil, html_options = nil, &block)
    html_options, options, name = options, name, capture(&block) if block

    html_options ||= {}
    html_options[:target] = '_blank'
    html_options[:class] = [*html_options[:class], 'usa-link--external']

    name = ERB::Util.unwrapped_html_escape(name).rstrip.html_safe # rubocop:disable Rails/OutputSafety
    name << content_tag('span', t('links.new_tab'), class: 'usa-sr-only')

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
