class UxDumper
  SCREENSHOT_DIR = 'screenshots'

  attr_reader :analytics

  def initialize(name)
    @name = name
    @slides = []
    @events_before_first_screenshot = {}
    @analytics = FakeAnalytics.new
  end

  def file_basename(page)
    parsed_url = URI(page.driver.current_url)
    Pathname.new("#{SCREENSHOT_DIR}#{parsed_url.path}")
  end

  def screenshot_path
    Pathname.new("#{@name}-screenshots/slide-#{@slides.length}.png")
  end

  def attach_events_to_last_slide
    if @slides.empty?
      @events_before_first_screenshot = analytics.events.dup
    else
      @slides.last[:events] = analytics.events.dup
    end
    analytics.events.clear
  end

  def resize_to_show_everything(page)
    width = page.driver.execute_script(
      'return Math.max(' \
      '  document.body.scrollWidth,' \
      '  document.body.offsetWidth,' \
      '  document.documentElement.clientWidth,' \
      '  document.documentElement.scrollWidth,' \
      '  document.documentElement.offsetWidth' \
      ') + 100;',
    )
    height = page.driver.execute_script(
      'return Math.max(' \
      '  document.body.scrollHeight,' \
      '  document.body.offsetHeight,' \
      '  document.documentElement.clientHeight,' \
      '  document.documentElement.scrollHeight,' \
      '  document.documentElement.offsetHeight' \
      ') + 100;',
    )

    page.driver.resize_window_to(page.driver.current_window_handle, width, height)
  end

  def take_screenshot(page)
    attach_events_to_last_slide

    resize_to_show_everything(page)
    FileUtils.mkdir_p(screenshot_path.dirname)
    page.driver.browser.save_screenshot(screenshot_path)

    @slides << { path: page.current_path, image: screenshot_path, links: links_out_of(page) }
  end

  def links_out_of(page)
    links = page.all(:css, 'a').map { |link| link['href'] }
    forms = page.all(:css, 'form').map { |form| form['action'] }
    (links + forms).
      reject { |url| URI(url).scheme == 'https' }.
      map { |url| URI(url).path }.
      compact.
      sort.
      uniq
  end

  def dump_path(slide)
    "## #{slide[:path]}"
  end

  def dump_image(slide)
    "![#{slide[:path]}](#{slide[:image]})"
  end

  def dump_links(slide)
    "#### links\n\n" +
      (slide[:links]&.map { |link| "- `#{link}`" }&.join("\n") || '') +
      "\n\n"
  end

  def dump_events(events)
    "#### events\n\n" \
    "<table>\n" \
    "<tr><th>Event</th><th>Parameters</th></tr>\n" +
      (events.map { |key, value|
         "<tr><td>#{key}</td><td>#{value}</td></tr>"
       }&.join("\n") || '') +
      "\n" \
      "</table>\n\n"
  end

  def dump_slide_events(slide)
    dump_events(slide[:events]) if slide[:events]
  end

  def dump_events_before_first_screenshot
    "## Before first slide\n\n" \
    "#{dump_events(@events_before_first_screenshot)}"
  end

  def finish
    attach_events_to_last_slide

    File.open("#{@name}.md", 'w') do |f|
      f.puts dump_events_before_first_screenshot

      @slides.each do |slide|
        f.puts dump_path(slide)
        f.puts dump_image(slide)
        f.puts dump_links(slide)
        f.puts dump_slide_events(slide)
        f.puts '---'
      end
      f.puts
    end
  end
end
