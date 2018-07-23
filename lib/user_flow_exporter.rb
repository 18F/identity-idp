# This module is part of the User Flows toolchest
#
# UserFlowExporter.run - scrapes user flows for use on the web
#
# Dependencies:
#   - Must be running the application locally eg (localhost:3000)
#   - Must have wget installed and available on your PATH
#
# Executing:
#   Start the application with:
#     $ make run
#   Export flows with:
#     $ RAILS_ASSET_HOST=localhost:3000 FEDERALIST_PATH=/site/user/repo rake spec:user_flows:web
#   Use the files output to public/<FEDERALIST PATH> in a Github repo connected to Federalist
#     $ cp -r ./public/site/user/repo ~/code/login-user-flows
#   And commit the changes in the Federalist repo!

module UserFlowExporter
  ASSET_HOST = ENV['RAILS_ASSET_HOST'] || 'localhost:3000'
  # Coming soon: signal testing for different devices
  # USER_AGENT = "Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.0.3) Gecko/2008092416 Firefox/3.0.3"
  FEDERALIST_PATH = ENV['FEDERALIST_PATH'] || '/flows_export/'

  def self.run
    Kernel.puts "Preparing to scrape user flows...\n"
    url = "http://#{ASSET_HOST}/user_flows/"
    # The web-friendly flows are still output to the public directory
    # in order to quickly test the content by visiting your locally
    # hosted application (eg. localhost:3000/site/18f/identity-ux/user_flows)

    if FEDERALIST_PATH[0] != '/'
      raise 'Federalist path must start with a slash (eg. /site/18f/identity-ux)'
    end

    output_dir = "public#{FEDERALIST_PATH}"

    # -r = recursively mirrors site
    # -H = span hosts (e.g. include assets from other domains)
    # -p = download all assets associated with the page
    # --no-host-directories = removes domain prefix from output path
    # -P = output prefix (a.k.a the directory to dump the assets)
    # --domains = whitelist of domains to include when following links
    scrape_cmd = "wget -r -H -p --no-host-directories " \
                "-P '#{output_dir}' " \
                "--domains 'localhost' " \
                "'#{url}'"
    system(scrape_cmd)

    massage_html(output_dir)
    massage_assets(output_dir)

    Kernel.puts 'Done! The user flows are now prepared for use on the interwebs!'
  end

  private

  def self.massage_html(dir)
    Dir.glob("#{dir}/**/*.html") do |html|
      File.open(html) do |file|
        path = file.path
        contents = File.read(path)
        contents.gsub!("http://#{ASSET_HOST}/", "#{FEDERALIST_PATH}/")
        contents.gsub!('.css?body=1', '.css')
        contents.gsub!('.js?body=1', '.js')
        contents.gsub!('href="/assets/', "href=\"#{FEDERALIST_PATH}/assets/")
        contents.gsub!('src="/assets/', "src=\"#{FEDERALIST_PATH}/assets/")
        contents.gsub!("href='/user_flows/", "href='#{FEDERALIST_PATH}/user_flows/")

        contents.gsub!("<base href='#{ASSET_HOST}' />", "<base href='#{FEDERALIST_PATH}/' />")

        File.open(path, "w") {|file| file.puts contents }
        Kernel.puts "Updated #{path} references"
      end
    end
  end

  def self.massage_assets(dir)
    Dir.glob("#{dir}/assets/**/**") do |file|
      if file[-11..-1] == '.css?body=1'
        new_filename = file.gsub('.css?body=1', '.css')
        `mv #{file} #{new_filename}`
        Kernel.puts "Moved #{file} to #{new_filename}"
      end

      if file[-10..-1] == '.js?body=1'
        new_filename = file.gsub('.js?body=1', '.js')
        `mv #{file} #{new_filename}`
        Kernel.puts "Moved #{file} to #{new_filename}"
      end
    end
  end
end
