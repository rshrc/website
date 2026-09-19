# frozen_string_literal: true

require "date"
require "time"
require "yaml"
require_relative "site"
require_relative "excerpt"

# An essay, published exactly the way tool/htmlgen.dart decides: a note in the
# markdown directory with front matter, `publish: true` and a `created` date.
class Article < Data.define(:title, :slug, :created, :opening, :minutes)
  FRONT_MATTER = /^\s*-{3,}\s*$/
  WORDS_PER_MINUTE = 230

  # Newest first. Several articles share a date, so ties go by title.
  def self.published
    Site.markdown_dir.glob("*.md").filter_map { from(_1) }
        .reject(&:archive?)
        .sort_by { [-_1.created.to_i, _1.title.downcase] }
  end

  def self.from(file)
    lines = file.readlines(encoding: "utf-8")
    return unless lines.first&.match?(FRONT_MATTER)

    close = lines[1..].index { _1.match?(FRONT_MATTER) } or return
    meta  = YAML.safe_load(lines[1, close].join, permitted_classes: [Date, Time], symbolize_names: true) || {}
    return unless meta[:publish] == true && meta[:created]

    body = lines[(close + 2)..].join
    name = file.basename(".md").to_s
    new(title: (meta[:title] || name).to_s, slug: Site.slugify(name), created: time(meta[:created]),
        opening: Excerpt.of(body), minutes: [(body.split.size / WORDS_PER_MINUTE.to_f).ceil, 1].max)
  end

  def self.time(value)
    case value
    when Time then value
    when Date then value.to_time
    else Time.parse(value.to_s)
    end
  end

  # Index.md becomes /text/index.html, the archive page itself.
  def archive? = slug == "index"

  def path = "/text/#{slug}.html"
  def url  = "#{Site::URL}#{path}"

  def to_markdown = "* [#{title.gsub(/([\\\[\]*_`])/) { "\\#{$1}" }}](#{url})"
end
