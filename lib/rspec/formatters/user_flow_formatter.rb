require 'rails_helper'

Capybara.save_path = Rails.root.join('public', 'user_flows')
Capybara::Screenshot.prune_strategy = :keep_last_run

# Capybara's `save_page` does not return anything. This is a hack to
# capture the path of the screenshot so that it can be embedded in
# the HTML output of this formatter
# rubocop:disable Style/GlobalVars
Capybara::Screenshot.after_save_html do |path|
  filename = path.split('/').last
  uri = Capybara.save_path.to_s.split('public').last + '/' + filename
  $cur_screenshot_link = uri
end

class UserFlowFormatter < RSpec::Core::Formatters::DocumentationFormatter
  # This registers the notifications this formatter supports, and tells
  # us that this was written against the RSpec 3.x formatter API.
  RSpec::Core::Formatters.register self, :initialize,
                                   :example_passed,
                                   :example_group_finished,
                                   :example_group_started,
                                   :stop

  def initialize(output)
    @html = '<html><head><link href="/assets/application.self.css" rel="stylesheet"></head>' \
            '<body class="p2 container black">' \
            '<h1 class="p2 my2 inline-block navy border border-dashed">' \
            '<img class="mr1 align-middle" src="/assets/logo.svg" width="140">' \
            '<span class="inline-block">/ user flows</span></h1>' \
            '<pre class="h5 line-height-2 sans-serif">'
    @user_flows_html_file = Capybara.save_path.join('index.html').to_s
    super
  end

  def example_passed(notification)
    example = notification.example
    indent = '       ' * example.metadata[:scoped_id].split(':').size
    @html << "<br>#{indent}<a class='underline' href='#{$cur_screenshot_link}'>" \
             "#{example.description} &raquo;</a>"

    super
  end

  def example_group_started(notification)
    indent = super

    @html << '<div class="mt1">'
    @html << '       ' * indent
    @html << notification.group.description
  end

  def example_group_finished(notification)
    @html << '</div>'
    super
  end

  def stop(_notification)
    Kernel.puts "Complete!\n"
    @html += '</pre></body></html>'
    File.open(@user_flows_html_file, 'wb') do |file|
      file.write(@html)
    end

    Kernel.puts 'User flows output to:'
    Kernel.puts flows_output_url
  end

  private

  def flows_output_url
    host = Rails.application.config.action_controller.asset_host || 'localhost:3000'
    protocol = host.match?(/localhost/) ? 'http://' : 'https://'

    "#{protocol}#{host}/user_flows"
  end
end
# rubocop:enable Style/GlobalVars
