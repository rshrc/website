# frozen_string_literal: true

# The opening of a piece of writing, sized for a hover card: about four or
# five lines, which at the card's width is 200 to 270 characters.
#
# Starts at the first real paragraph and reads on into the next ones until the
# card is full, stopping at the first heading, list, image or code block, and
# always on a whole sentence. Poems keep their line breaks as slashes, which
# is how verse gets quoted.
module Excerpt
  TARGET = 200
  LIMIT  = 270
  PROSE  = ->(paragraph) { paragraph.length > 60 && !paragraph.match?(/\A(#|!\[|<|>|\||[*+-]\s|\d+\.\s)/) }

  module_function

  def of(markdown)
    paragraphs = markdown.gsub(/```.*?```/m, "\n\n[code]\n\n").split(/\n\s*\n/).map(&:strip).reject(&:empty?)
    first = paragraphs.index(&PROSE) or return

    lines = paragraphs[first].lines.map(&:strip).reject(&:empty?)
    verse?(lines) ? verse(lines) : prose(paragraphs[first..].take_while(&PROSE))
  end

  def verse?(lines) = lines.size >= 3 && lines.all? { _1.length < 80 }

  def verse(lines)
    quoted = truncate(plain(lines.first(5).join(" / ")))
    # A poem cut mid-stanza shouldn't end on a dangling comma.
    lines.size > 5 && !quoted.end_with?("…") ? "#{quoted.sub(/[,;:]\z/, "")} …" : quoted
  end

  def prose(paragraphs)
    sentences = paragraphs.flat_map { plain(_1.lines.map(&:strip).join(" ")).squeeze(" ").split(/(?<=[.!?])\s+/) }

    picked = sentences.inject("") do |so_far, sentence|
      longer = so_far.empty? ? sentence : "#{so_far} #{sentence}"
      break so_far if so_far.length >= TARGET || (!so_far.empty? && longer.length > LIMIT)

      longer
    end
    truncate(picked)
  end

  # Markdown and Obsidian syntax, down to the words a reader would see.
  def plain(markdown)
    markdown.gsub(/!\[[^\]]*\]\([^)]*\)/, "")
            .gsub(/!\[\[[^\]]*\]\]/, "")
            .gsub(/\[\[(?:[^\]|]*\|)?([^\]]*)\]\]/, '\1')
            .gsub(/\[([^\]]+)\]\([^)]*\)/, '\1')
            .gsub(/<[^>]+>/, "")
            .gsub(/`([^`]*)`/, '\1')
            .gsub(/(\*\*|__)(.+?)\1/, '\2')
            .gsub(/(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?!\w)/, '\1')
            .gsub(/(?<!\w)_(?!\s)(.+?)(?<!\s)_(?!\w)/, '\1')
  end

  def truncate(text)
    return text if text.length <= LIMIT

    "#{text[0, LIMIT].sub(/\s+\S*\z/, "").sub(/[,;:.]\z/, "")}…"
  end
end
