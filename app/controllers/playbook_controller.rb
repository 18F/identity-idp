class PlaybookController < ApplicationController
  layout false

  def about
  end

  def index
    @principles = [
      ['pb-users', 'graphic-users', 'Focus on user needs'],
      ['pb-transparent', 'graphic-venn', 'Be transparent about how it works'],
      ['pb-flexible', 'graphic-half-circle', 'Build a flexible product'],
      ['pb-privacy', 'graphic-locks', 'Use modern privacy practices'],
      ['pb-security', 'graphic-hex', 'Create responsive security systems']
    ]
  end

  def principles
  end
end
