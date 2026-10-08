#!/usr/bin/env ruby
# frozen_string_literal: true

# Checks that every URL in the sitemap has a page in the build.
# Exits 1 when some are missing, 2 when there's nothing to check.

require "optparse"
require "rexml/document"
require "uri"

sitemap, build = "sitemap.xml", "build"
OptionParser.new do |opts|
  opts.on("--sitemap PATH") { sitemap = _1 }
  opts.on("--build-dir PATH") { build = _1 }
end.parse!

def fail!(message)
  warn "ERROR: #{message}"
  exit 2
end

fail! "sitemap not found: #{sitemap}" unless File.exist?(sitemap)
fail! "build dir not found: #{build}" unless Dir.exist?(build)

urls = REXML::XPath.match(REXML::Document.new(File.read(sitemap)), "//xmlns:url/xmlns:loc").map { _1.text.to_s.strip }
fail! "no URLs found in sitemap." if urls.empty?

# A directory URL is served from its index.html, as Firebase does.
missing = urls.filter_map do |loc|
  path = URI.parse(loc).path
  page = File.join(build, path.delete_prefix("/"), *("index.html" if path.end_with?("/")))
  "#{loc} -> missing #{page}" unless File.exist?(page)
end

if missing.any?
  puts "FAIL: #{missing.size} of #{urls.size} sitemap URLs are not reachable:"
  missing.each { puts "  - #{_1}" }
  exit 1
end

puts "PASS: all #{urls.size} sitemap URLs map to existing build artifacts."
