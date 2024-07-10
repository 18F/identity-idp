class UxDumper
  SCREENSHOT_DIR = 'screenshots'

  attr_reader :strings

  def initialize(name)
    @name = name
    @slides = []
    @strings = []
  end

  def file_basename(page)
    parsed_url = URI(page.driver.current_url)
    Pathname.new("#{SCREENSHOT_DIR}#{parsed_url.path}")
  end

  def screenshot_path
    Pathname.new("#{@name}-screenshots/slide-#{@slides.length}.png")
  end

  def add_string(key, string)
    puts "UxDumper#add_string(#{key}, #{string.inspect})"
    @strings << [key, string]
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
    resize_to_show_everything(page)
    FileUtils.mkdir_p(screenshot_path.dirname)
    page.driver.browser.save_screenshot(screenshot_path)

    @slides << { path: page.current_path, image: screenshot_path, strings: strings_for_last_slide }
  end

  def strings_for_last_slide
    return_value = @strings
    @strings = []
    return_value
  end

  def dump_path(slide)
    "## #{slide[:path]}"
  end

  def dump_image(slide)
    "![#{slide[:path]}](#{slide[:image]})"
  end

  def dump_strings(slide)
    slide[:strings].map do |string_pair|
      key = string_pair.first
      string = string_pair.second

      "`#{key}:         #{string.inspect}`<br />"
    end.join + '<br />'
  end

  def finish
    File.open("#{@name}.md", 'w') do |f|
      @slides.each do |slide|
        f.puts dump_path(slide)
        f.puts dump_image(slide)
        f.puts
        f.puts dump_strings(slide)
        f.puts
        f.puts '---'
      end
      f.puts
    end
  end
end
