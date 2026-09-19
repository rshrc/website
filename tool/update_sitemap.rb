#!/usr/bin/env ruby
# frozen_string_literal: true

# Rewrites sitemap.xml from the articles in markdowns/, newest first, keeping
# a timestamped backup of the old one. An article's date is its front matter
# `created`, or the file's modified time when that's missing.

require "fileutils"
require "time"
require_relative "lib/site"

MARKDOWNS = Site.path("markdowns")
SITEMAP   = Site.path("sitemap.xml")

def created(file)
  lines = file.readlines(encoding: "utf-8")
  return unless lines.first&.strip == "---"

  value = lines.drop(1).take_while { _1.strip != "---" }
               .filter_map { _1[/^\s*created\s*:\s*(.+)$/i, 1] }.first&.strip&.gsub(/\A['"]|['"]\z/, "")
  Time.parse(value).utc if value && !value.empty?
rescue ArgumentError
  nil
end

def url(loc, date, priority)
  ["  <url>", "    <loc>#{loc}</loc>", "    <lastmod>#{date.strftime("%Y-%m-%d")}</lastmod>",
   "    <priority>#{priority}</priority>", "  </url>"]
end

unless MARKDOWNS.directory?
  warn "Error markdown dir not found: #{MARKDOWNS}"
  exit 2
end

articles = MARKDOWNS.children.sort.select { _1.file? && _1.extname.downcase == ".md" }.map do |file|
  [created(file) || file.mtime.utc, Site.slugify(file.basename(".md").to_s)]
end
puts "No markdown files found, writing sitemap with only homepage." if articles.empty?

if SITEMAP.exist?
  backup = "#{SITEMAP}.bak.#{Time.now.utc.strftime("%Y%m%dT%H%M%SZ")}"
  FileUtils.cp(SITEMAP, backup)
  puts "Backed up existing sitemap to #{backup}"
end

lines = ['<?xml version="1.0" encoding="UTF-8"?>', '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
         *url("#{Site::URL}/", Time.now.utc, "1.00"),
         *articles.sort_by { -_1.first.to_i }.flat_map { |date, slug| url("#{Site::URL}/text/#{slug}.html", date, "0.80") },
         "</urlset>"]
SITEMAP.write("#{lines.join("\n")}\n")
puts "Wrote sitemap to #{SITEMAP}"
