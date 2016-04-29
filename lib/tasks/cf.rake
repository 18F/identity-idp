# From http://docs.cloudfoundry.org/buildpacks/ruby/ruby-tips.html#rake

require File.expand_path('../../server_env', __FILE__)
	namespace :cf do
	  desc "Only run on the first application instance"
	  task :on_first_instance do
	    unless ServerEnv.instance_index == 0
	      exit(0)
	    end
	  end
	end
