#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'rexml/document'
require 'uri'

options = {
  sitemap: 'sitemap.xml',
  build_dir: 'build'
}

OptionParser.new do |opts|
  opts.on('--sitemap PATH') { |v| options[:sitemap] = v }
  opts.on('--build-dir PATH') { |v| options[:build_dir] = v }
end.parse!

unless File.exist?(options[:sitemap])
  warn "ERROR: sitemap not found: #{options[:sitemap]}"
  exit 2
end

unless Dir.exist?(options[:build_dir])
  warn "ERROR: build dir not found: #{options[:build_dir]}"
  exit 2
end

xml = REXML::Document.new(File.read(options[:sitemap]))
locs = []
REXML::XPath.each(xml, "//xmlns:url/xmlns:loc") { |node| locs << node.text.to_s.strip }

checked = 0
failures = []

locs.each do |loc|
  uri = URI.parse(loc)
  path = uri.path
  next unless path.start_with?('/text/') && path.end_with?('.html')

  checked += 1
  rel = path.sub(%r{\A/}, '')
  artifact = File.join(options[:build_dir], rel)
  failures << "#{loc} -> missing #{artifact}" unless File.exist?(artifact)
end

if checked.zero?
  warn 'ERROR: no blog URLs found in sitemap (/text/*.html).'
  exit 2
end

if failures.any?
  puts "FAIL: #{failures.length} of #{checked} sitemap blog URLs are not reachable:"
  failures.each { |f| puts "  - #{f}" }
  exit 1
end

puts "PASS: all #{checked} sitemap blog URLs map to existing build artifacts."
