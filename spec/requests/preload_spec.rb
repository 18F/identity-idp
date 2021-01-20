require 'rails_helper'

describe 'asset preloading' do
  it 'does not preload old IE shims' do
    get root_path

    preloaded = parse_preloaded(response.headers['Link'])
    shiv_url = ActionController::Base.helpers.asset_url('html5shiv')
    expect(preloaded).to_not include(shiv_url)
  end

  private

  def parse_preloaded(value)
    value.split(',').
      filter { |part| part.split(';').map(&:strip).include?('rel=preload') }.
      map { |part| part[/<(.+?)>/, 1] }
  end
end
