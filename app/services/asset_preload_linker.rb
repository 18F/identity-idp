# frozen_string_literal: true

class AssetPreloadLinker
  def self.append(response:, as:, url:, crossorigin: false, integrity: nil)
    header = response.headers['Link'] || ''
    header += ',' if header.present?
    header += "<#{url}>;rel=preload;as=#{as}"
    header += ';crossorigin' if crossorigin
    header += ";integrity=#{integrity}" if integrity
    response.headers['Link'] = header
  end
end
