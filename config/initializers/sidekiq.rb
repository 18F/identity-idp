# Redis is the storage for Sidekiq.
# we assume defaults are fine for test/development.
# https://github.com/mperham/sidekiq/wiki/Using-Redis
#if Rails.env.production?
  vcap = ENV["VCAP_SERVICES"]
  vcap_config = JSON.parse(vcap)
  vcap_config.keys.each do |vcap_key|
    if vcap_key.match(/redis\d+-swarm/)
      redis_config = vcap_config[vcap_key][0]['credentials']
      redis_url = "redis://:#{redis_config['password']}@#{redis_config['hostname']}:#{redis_config['port']}"
      #STDERR.puts "REDIS_URL=#{redis_url}"
      ENV['REDIS_PROVIDER'] ||= redis_url
      ENV['REDIS_URL'] ||= redis_url
    end
  end
#end
