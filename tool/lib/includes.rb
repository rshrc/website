# frozen_string_literal: true

# Templates pull their CSS and JavaScript in from src/ at build time, so each
# page still ships as a single HTML file:
#
#   <style>/* INCLUDE css/home.css */</style>
#
# Included files can include others the same way. A marker on a line of its
# own is replaced along with its indent and line break, so the included file's
# own formatting comes through exactly as written.
module Includes
  PATTERN = %r{[ \t]*/\* INCLUDE ([\w/.-]+) \*/(?:[ \t]*\n)?}
  SRC = File.expand_path("../../src", __dir__)

  def self.expand(text)
    text.gsub(PATTERN) { expand(File.read(File.join(SRC, Regexp.last_match(1)))) }
  end
end
