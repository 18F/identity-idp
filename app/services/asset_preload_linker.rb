# frozen_string_literal: true

class AssetPreloadLinker
  def self.append(headers:, as:, url:, crossorigin: false, integrity: nil)
    header = headers['Link'] || ''
    header += ',' if header.present?
    header += "<#{url}>;rel=preload;as=#{as}"
    header += ';crossorigin' if crossorigin
    header += ";integrity=#{integrity}" if integrity
    headers['Link'] = header
  end
end
