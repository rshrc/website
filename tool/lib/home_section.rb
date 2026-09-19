# frozen_string_literal: true

require "yaml"
require_relative "site"

# One list on the homepage, written as src/home/<name>.yaml and placed in
# src/index.md with <!-- SECTION name -->.
#
# Items have `text`, and optionally a `url` (making the text a link), a `note`
# (Markdown written after it, exactly as given, so it can carry its own
# separator or links), a `preview` for its hover card, and `children`.
class HomeSection
  DIR         = Site.path("src/home")
  FIELDS      = %i[title level intro items].freeze
  ITEM_FIELDS = %i[text url note preview children].freeze

  def self.names = DIR.glob("*.yaml").map { _1.basename(".yaml").to_s }

  def self.load(name)
    file = DIR.join("#{name}.yaml")
    raise "index.md asks for section '#{name}' but #{file} does not exist" unless file.exist?

    new(name, YAML.safe_load(file.read(encoding: "utf-8"), symbolize_names: true) || {})
  end

  def initialize(name, data)
    @name, @data = name, data
    unknown(data.keys - FIELDS, "#{name}.yaml")
    raise "#{name}.yaml: needs a `title`" if blank?(data[:title])
  end

  def to_markdown(previews)
    items = (@data[:items] || []).each_with_index.map do |item, i|
      list_item(item, "#{@name}.yaml item ##{i + 1} (#{item[:text]})", previews)
    end

    [ "#{"#" * (@data[:level] || 2)} #{@data[:title]}",
      (@data[:intro].to_s.strip unless blank?(@data[:intro])),
      (items.join("\n") if items.any?) ].compact.join("\n\n")
  end

  private
    def list_item(item, where, previews, depth = 0)
      unknown(item.keys - ITEM_FIELDS, where)
      raise "#{where}: every item needs `text`" if blank?(item[:text])

      preview(item, where, previews)

      head = item[:url] ? "[#{item[:text]}](#{item[:url]})" : item[:text].to_s
      line = "#{"  " * depth}#{depth.zero? ? "*" : "-"} #{head}"
      line += " #{item[:note]}" unless blank?(item[:note])

      children = (item[:children] || []).each_with_index.map do |child, i|
        list_item(child, "#{where} > child ##{i + 1}", previews, depth + 1)
      end
      [line, *children].join("\n")
    end

    # A card attaches to the item's `url`, or failing that to the first link
    # inside its `text`, as in "Articles [here](...)".
    def preview(item, where, previews)
      return if blank?(item[:preview])

      url = item[:url] || item[:text].to_s[/\]\(([^)\s]+)\)/, 1]
      raise "#{where}: has a `preview` but no link to attach it to" unless url

      previews.add(url, item[:preview].to_s.strip)
    end

    def unknown(fields, where)
      warn "#{where}: unknown field(s) #{fields.join(", ")}" if fields.any?
    end

    def blank?(value) = value.to_s.strip.empty?
end
