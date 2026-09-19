#!/usr/bin/env ruby
# frozen_string_literal: true

# `make run`: builds the site, serves it on localhost, and rebuilds whenever
# anything under src/, markdowns/ or tool/ changes.

require "digest"
require_relative "lib/site"

PORT          = ENV.fetch("PORT", "3002")
WATCHED_DIRS  = %w[src markdowns tool].freeze
WATCHED_FILES = %w[Makefile htmlgen.toml sitemap.xml robots.txt].freeze

# The build writes these itself. Watching them would make every build set off
# the next one.
GENERATED = %w[src/.index.generated.md src/.index.template.generated.html].freeze

def fingerprint
  files = WATCHED_DIRS.flat_map { Dir.glob("#{_1}/**/*", File::FNM_DOTMATCH, base: Site::ROOT) } + WATCHED_FILES
  stamps = (files - GENERATED).map { Site.path(_1) }.select(&:file?).sort.map { "#{_1}:#{_1.mtime.to_f}" }
  Digest::SHA256.hexdigest(stamps.join("|"))
end

# Links in the build are absolute, for production. Dropping the domain makes
# them work on localhost.
def localize_links
  Site.path("build").glob("**/*.html").each do |page|
    html = page.read
    page.write(html.gsub(Site::URL, "")) if html.include?(Site::URL)
  end
end

def build
  puts "[watch] rebuilding..."
  built = system("make", "builder", chdir: Site::ROOT)
  localize_links if built
  puts built ? "[watch] build ok" : "[watch] build failed"
end

build
puts "[watch] starting static server at http://localhost:#{PORT}"
server = spawn("serve", "build", "-l", PORT, chdir: Site::ROOT)

%i[INT TERM].each do |signal|
  trap(signal) do
    puts "\n[watch] shutting down..."
    Process.kill("TERM", server) rescue nil
    exit
  end
end

last = fingerprint
loop do
  sleep 1
  next if (now = fingerprint) == last

  last = now
  build
end
