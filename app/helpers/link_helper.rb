module LinkHelper
  EXTERNAL_LINK_CLASSES = ['usa-link', 'usa-link--external'].freeze
  ALT_EXTERNAL_LINK_CLASSES = ['usa-link--alt', 'usa-link--external'].freeze

  def new_window_link_to(name = nil, url = nil, html_options = nil)
    html_options ||= {}
    html_options[:class] ||= html_options[:class].to_s

    classes = html_options[:class].split(' ')

    if classes.include?('usa-link--alt')
      classes.concat(ALT_EXTERNAL_LINK_CLASSES)
    else
      classes.concat(EXTERNAL_LINK_CLASSES)
    end

    html_options[:class] = classes.uniq.join(' ')

    link_to(url, html_options) do
      content_tag('span', name) +
        content_tag('span', t('links.new_window'), class: 'usa-sr-only')
    end
  end
end
