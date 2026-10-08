#!/usr/bin/env ruby
# frozen_string_literal: true

# Rewrites sitemap.xml from everything the build publishes, keeping a
# timestamped backup of the old one: the homepage, /text/ and its articles,
# /games/ and each game, and the shelf. An article's date is its front matter
# `created`; a generated page's is when its source last changed.

require "fileutils"
require "time"
require "yaml"
require_relative "lib/site"
require_relative "lib/article"

SITEMAP = Site.path("sitemap.xml")

# The newest modification time among files matching the globs.
def changed(*globs)
  globs.flat_map { Site::ROOT.glob(_1) }.select(&:file?).map(&:mtime).max&.utc || Time.now.utc
end

def url(path, date, priority)
  ["  <url>", "    <loc>#{Site::URL}#{path}</loc>", "    <lastmod>#{date.strftime("%Y-%m-%d")}</lastmod>",
   "    <priority>#{priority}</priority>", "  </url>"]
end

articles = Article.published
games    = YAML.safe_load(Site.path("src/games/games.yaml").read, symbolize_names: true)[:games] || []
shared   = %w[src/games/shared/**/* src/games/*.html src/games/games.yaml]

pages = [
  ["/", Time.now.utc, "1.00"],
  ["/text/", articles.map(&:created).max || Time.now.utc, "0.90"],
  *articles.map { [_1.path, _1.created, "0.80"] },
  ["/games/", changed(*shared), "0.70"],
  *games.map { ["/games/#{_1[:slug]}.html", changed("src/games/#{_1[:slug]}/**/*", *shared), "0.60"] },
  ["/books/shelf.html", changed("src/books/shelf.*"), "0.70"],
]

if SITEMAP.exist?
  backup = "#{SITEMAP}.bak.#{Time.now.utc.strftime("%Y%m%dT%H%M%SZ")}"
  FileUtils.cp(SITEMAP, backup)
  puts "Backed up existing sitemap to #{backup}"
end

lines = ['<?xml version="1.0" encoding="UTF-8"?>', '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
         *pages.flat_map { url(*_1) }, "</urlset>"]
SITEMAP.write("#{lines.join("\n")}\n")
puts "Wrote #{pages.size} URLs to #{SITEMAP}"
