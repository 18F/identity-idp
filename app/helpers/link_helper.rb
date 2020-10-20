module LinkHelper
  EXTERNAL_LINK_CLASS = 'usa-link--external'.freeze

  def new_window_link_to(name = nil, options = nil, html_options = nil, &block)
    if block_given?
      html_options = options
      options = name
      name = block
    end
    options ||= {}

    html_options = convert_options_to_data_attributes(options, html_options)

    url = url_for(options)
    html_options['href'] ||= url
    html_options['class'] ||= html_options['class'].to_s
    html_options['target'] = '_blank'

    classes = html_options['class'].split(' ').append(EXTERNAL_LINK_CLASS)

    html_options['class'] = classes.uniq.join(' ')

    if block_given?
      link_to(url, html_options) do
        yield(block)
        concat content_tag('span', t('links.new_window'), class: 'usa-sr-only')
      end
    else
      link_to(url, html_options) do
        content_tag('span', name) +
          content_tag('span', t('links.new_window'), class: 'usa-sr-only')
      end
    end
  end
end
