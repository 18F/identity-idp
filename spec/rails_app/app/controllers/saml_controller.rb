class SamlController < ApplicationController

  def consume
    response = OneLogin::RubySaml::Response.new(params[:SAMLResponse])
    render :text => response.name_id
  end

end
