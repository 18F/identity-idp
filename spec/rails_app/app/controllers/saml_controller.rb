class SamlController < ApplicationController

  def consume
    response = Onelogin::Saml::Response.new(params[:SAMLResponse])
    render :text => response.name_id
  end

end