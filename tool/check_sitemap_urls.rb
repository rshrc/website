#!/usr/bin/env ruby
# frozen_string_literal: true

# Checks that every article URL in the sitemap has a page in the build.
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

articles = REXML::XPath.match(REXML::Document.new(File.read(sitemap)), "//xmlns:url/xmlns:loc")
                       .map { _1.text.to_s.strip }
                       .select { URI.parse(_1).path.then { |path| path.start_with?("/text/") && path.end_with?(".html") } }
fail! "no blog URLs found in sitemap (/text/*.html)." if articles.empty?

missing = articles.filter_map do |loc|
  page = File.join(build, URI.parse(loc).path.delete_prefix("/"))
  "#{loc} -> missing #{page}" unless File.exist?(page)
end

if missing.any?
  puts "FAIL: #{missing.size} of #{articles.size} sitemap blog URLs are not reachable:"
  missing.each { puts "  - #{_1}" }
  exit 1
end

puts "PASS: all #{articles.size} sitemap blog URLs map to existing build artifacts."
