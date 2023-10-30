#!/usr/bin/env ruby
require 'faraday'

response = Faraday.get("https://raw.githubusercontent.com/fnando/email_data/46d7d9aab2cd7f5c26709f27c02932f7c19f59d0/data/disposable_domains.txt")

disposable_domains_file="disposable_domains/disposable-domains.txt"
