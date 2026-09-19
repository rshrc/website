#!/usr/bin/env ruby
# frozen_string_literal: true

# Fetches cover art for every Spotify link in src/home/*.yaml, so music links
# get a picture in their hover card. Run it after adding links: `make covers`.
#
# Builds stay offline. They only read what this leaves behind:
#
#   src/home/covers.json      title and kind for each Spotify ID
#   web/img/covers/<id>.jpg   the art, at 128px

require "json"
require "net/http"
require "tmpdir"
require_relative "lib/site"

INDEX    = Site.path("src/home/covers.json")
IMAGES   = Site.path("web/img/covers")
SECTIONS = Site.path("src/home").glob("*.yaml")

SPOTIFY_LINK = %r{https://open\.spotify\.com/(artist|album|track|playlist)/(\w+)}
SEARCH_LINK  = %r{https://open\.spotify\.com/search/\S+?(?=[)"\s])}

def image_for(id) = IMAGES.join("#{id}.jpg")

def oembed(kind, id)
  uri = URI("https://open.spotify.com/oembed")
  uri.query = URI.encode_www_form(url: "https://open.spotify.com/#{kind}/#{id}")
  JSON.parse(Net::HTTP.get(uri), symbolize_names: true)
end

def download_cover(url, id)
  Dir.mktmpdir do |dir|
    original = File.join(dir, "cover")
    File.binwrite(original, Net::HTTP.get(URI(url)))
    system("sips", "-s", "format", "jpeg", "-s", "formatOptions", "80", "-Z", "128",
           original, "--out", image_for(id).to_s, out: File::NULL, exception: true)
  end
end

covers = INDEX.exist? ? JSON.parse(INDEX.read, symbolize_names: true) : {}
links  = SECTIONS.flat_map { _1.read.scan(SPOTIFY_LINK) }.uniq.map { |kind, id| [kind.to_sym, id.to_sym] }
IMAGES.mkpath

links.each do |kind, id|
  next if covers[id] && image_for(id).exist?

  found = oembed(kind, id)
  download_cover(found.fetch(:thumbnail_url), id)
  covers[id] = { kind:, title: found.fetch(:title) }
  puts "fetched #{kind}: #{found[:title]}"
rescue StandardError => e
  warn "skipped #{kind}/#{id}: #{e.message}"
end

(covers.keys - links.map(&:last)).each do |gone|
  covers.delete(gone)
  image_for(gone).delete if image_for(gone).exist?
  puts "removed cover no longer linked: #{gone}"
end

INDEX.write(JSON.pretty_generate(covers.sort.to_h) + "\n")
puts "#{covers.size} covers for #{links.size} Spotify links"

SECTIONS.each do |section|
  section.read.scan(SEARCH_LINK).each do |search|
    warn "#{section.basename}: #{search} is a search link, so it has no cover. " \
         "Use Share > Copy link in Spotify instead."
  end
end
