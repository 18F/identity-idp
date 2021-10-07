require 'browser/aliases'
Browser::Base.include(Browser::Aliases)

# [Hash<String, Browser>]
BROWSER_CACHE = Hash.new { |h, user_agent| h[user_agent] = Browser.new(user_agent) }
