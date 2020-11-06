require 'yaml'

class AssetChecker
  ASSETS_FILE = 'app/views/idv/shared/_document_capture.html.erb'.freeze

  attr_reader :files, :assets_file

  def initialize(files, assets_file: ASSETS_FILE)
    @files = files
    @assets_file = assets_file
  end

  # @return [Boolean] true if any files are missing
  def check_files
    @asset_strings = load_included_strings(assets_file)
    files.any? { |f| file_has_missing?(f) }
  end

  def file_has_missing?(file)
    data = File.open(file).read
    missing_assets = find_missing(data, /\WgetAssetPath\(["'](.*?)['"]\)/, @asset_strings)
    if missing_assets.any?
      warn file
      missing_assets.each do |a|
        warn "Missing asset, #{a}"
      end
    end
    missing_assets.any?
  end

  def find_missing(file_data, pattern, source)
    strings = (file_data.scan pattern).flatten
    strings.reject { |s| source.include? s }
  end

  def load_included_strings(file)
    data = File.open(file).read
    key_data = data.split('<% asset_keys = [').last.split('] %>').first
    key_data.scan(/['"](.*)['"]/).flatten
  end
end
