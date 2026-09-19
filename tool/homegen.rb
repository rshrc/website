#!/usr/bin/env ruby
# frozen_string_literal: true

# Builds the homepage for spanify. src/index.md holds the prose and the page's
# layout, and marks where the generated parts go:
#
#   <!-- SECTION gigs -->        src/home/gigs.yaml, as a Markdown list
#   <!-- ESSAYS -->              every published article, newest first
#
# and the template gets the data for the hover cards:
#
#   <!-- GENERATED PREVIEWS -->  essay openings, YAML previews, Spotify covers
#
# It's all written out before spanify runs, so generated words fade in like
# every other word on the page.

require_relative "lib/site"
require_relative "lib/includes"
require_relative "lib/article"
require_relative "lib/home_section"
require_relative "lib/link_previews"

SECTION  = /<!-- SECTION ([a-z0-9_-]+) -->/
ESSAYS   = "<!-- ESSAYS -->"
PREVIEWS = "<!-- GENERATED PREVIEWS -->"

source   = Site.path("src/index.md").read(encoding: "utf-8")
template = Site.path("src/index.template.html").read(encoding: "utf-8")
raise "src/index.md has no #{ESSAYS} marker to fill in" unless source.include?(ESSAYS)
raise "src/index.template.html has no #{PREVIEWS} marker to fill in" unless template.include?(PREVIEWS)

placed = source.scan(SECTION).flatten
(HomeSection.names - placed).each { warn "src/home/#{_1}.yaml exists but index.md never places it" }

essays   = Article.published
previews = LinkPreviews.new(essay_count: essays.size)
essays.each { previews.add_essay(_1) }

markdown = source.gsub(SECTION) { HomeSection.load($1).to_markdown(previews) }
                 .sub(ESSAYS) { essays.map(&:to_markdown).join("\n") }
previews.add_covers(markdown)
page = Includes.expand(template).sub(PREVIEWS) { previews.to_script }

{ "src/.index.generated.md" => [markdown, "#{placed.size} sections, #{essays.size} essays"],
  "src/.index.template.generated.html" =>
    [page, "#{essays.count(&:opening)} of #{essays.size} essays and #{previews.written_count} other links with a card"] }
  .each do |file, (content, summary)|
    path = Site.path(file)
    puts "#{Site.write(path, content) ? "written" : "unchanged"} #{path} (#{summary})"
  end
