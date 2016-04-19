module Devise
  # Failure application that will be called every time :warden is thrown from
  # any strategy or hook. Responsible for redirect the user to the sign in
  # page based on current scope and mapping. If no scope is given, redirect
  # to the default_url.
  class FailureApp < ActionController::Metal
    protected

    def route(scope, register = false)
      if register
        :"new_#{scope}_registration_url"
      else
        :"new_#{scope}_session_url"
      end
    end

    def scope_url
      opts  = {}

      route = route(scope, session[:route_to_registration])

      opts[:format] = request_format unless skip_format?

      config = Rails.application.config

      if config.respond_to?(:relative_url_root) && config.relative_url_root.present?
        opts[:script_name] = config.relative_url_root
      end

      context = send(Devise.available_router_name)

      context.send(route, opts) if context.respond_to?(route)
    end
  end
end
