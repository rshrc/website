# frozen_string_literal: true

require "pathname"

# Where things live, and the few rules every generator has to agree on.
module Site
  ROOT  = Pathname(__dir__).join("../..").expand_path
  URL   = "https://banerjeerishi.com"
  HOSTS = %w[banerjeerishi.com www.banerjeerishi.com].freeze

  module_function

  def path(*parts) = ROOT.join(*parts)

  # Articles live wherever htmlgen.toml says (the Obsidian vault).
  def markdown_dir
    dir = path("htmlgen.toml").read[/^\s*markdown_directory\s*=\s*['"]([^'"]+)['"]/, 1]
    dir ? path(dir) : raise("markdown_directory is missing from htmlgen.toml")
  end

  # Same rules as _sanitizeFilename in tool/htmlgen.dart, so every link we
  # generate lands on a page htmlgen actually built.
  def slugify(text)
    slug = text.downcase.delete("'’").gsub(/[^a-z0-9]+/, "-").squeeze("-").gsub(/\A-+|-+\z/, "")
    slug.empty? ? "untitled" : slug[0, 255]
  end

  # Writes only when the content changed, and says whether it did. The dev
  # server rebuilds on file changes, so rewriting identical output from inside
  # a build would set off the next build, forever.
  def write(file, content)
    return false if file.exist? && file.read == content

    file.write(content)
    true
  end
end
