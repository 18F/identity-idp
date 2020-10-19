module LinkHelper
  EXTERNAL_LINK_CLASS = 'usa-link--external'.freeze

  def new_window_link_to(name = nil, url = nil, html_options = nil)
    html_options ||= {}
    html_options[:class] ||= html_options[:class].to_s
    html_options[:target] = '_blank'

    classes = html_options[:class].split(' ').append(EXTERNAL_LINK_CLASS)

    html_options[:class] = classes.uniq.join(' ')

    link_to(url, html_options) do
      content_tag('span', name) +
        content_tag('span', t('links.new_window'), class: 'usa-sr-only')
    end
  end
end
