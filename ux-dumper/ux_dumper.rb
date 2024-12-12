class UxDumper
  SCREENSHOT_DIR = 'screenshots'

  attr_reader :log_file

  def initialize(name)
    @name = name
    @slides = []
    @log_file = nil
  end

  def file_basename(page)
    parsed_url = URI(page.driver.current_url)
    Pathname.new("#{SCREENSHOT_DIR}#{parsed_url.path}")
  end

  def screenshot_path
    Pathname.new("#{@name}-screenshots/slide-#{@slides.length}.png")
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
    if !log_file
      @log_file = File.open('log/test.log', 'r')
    end
    return [] if !log_file

    return_value = []
    so_far = []
    log_file.each_line do |log_line|
      case log_line
      when /^translation request: ({.*})/
        so_far << JSON.parse($1)
      when /^{"method":"/
        return_value = so_far
        so_far = []
      end
    end

    puts "strings_for_last_slide: returning: #{JSON.pretty_generate(return_value)}"

    return_value
  end

  def dump_path(slide)
    "## #{slide[:path]}"
  end

  def dump_image(slide)
    "![#{slide[:path]}](#{slide[:image]})"
  end

  def dump_strings(slide)
    slide[:strings].map do |string_data|
      key = string_data['key']
      translations = string_data['translations']
      "`#{key}:`\n> en: #{translations['en'].inspect} es: #{translations['es'].inspect} fr: #{translations['fr'].inspect} zh: #{translations['zh'].inspect}\n\n"
    end.join('<br />') + '<br />'
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
