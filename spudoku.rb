#!/usr/bin/env ruby

require "rubygems"
require "bundler/setup"
require "sinatra"
require "http"
require "haml"
require "redcarpet"

# I think it's a terrible idea for DOM/JS to alter data-* names by
# camelcasing.  It maeans you have to search code for two names.  Haml
# joins the fray by converting _ in source to - in HTML.  I like
# snakecase and more importantly I don't want things to be renamed
# behind my back.

Haml::Options.defaults[:hyphenate_data_attrs] = false
Haml::Options.defaults[:format] = :html5

# Put helper methods in a module so they're accessible to unit tests,
# since Spudoku.new returns an instance of Sinatra::Wrapper which
# leaves the Spudoku instance methods inacccessible.

module Helpers
  def link_to(text, href)
    "<a href='#{href}'>#{text}</a>"
  end

  def snip(text)
    text =~ /(.*)^.*Snip.*/m
    $1 || text
  end
end

helpers Helpers

get "/" do
  level = params[:level] || "1"

  # Fetch a random puzzle of the requested level.

  solved, editmask = WebSudoku.get_puzzle(level)

  # Turn the strings into something more usable: an array of colors
  # strings, and an array of booleans, true if the position is part of
  # the setup.

  colors = solved.each_char.map{|c| COLORS[c.to_i - 1]}
  setup = editmask.each_char.map{|x| x == "0"}

  # Set up the colors array to pass to the view: each position gets a
  # hash with its setup color or nil if the position is not part of
  # the setup, and its solved color.

  colors = colors.zip(setup).map do |color, setup|
    {setup: setup ? color : nil, solved: color}
  end

  # Render the page.

  haml :main, locals: {level: level, colors: colors}
end

error do
  "Well that didn't work.  It's not your fault.  And it's not my fault either.  Well, probably not.  I recommend you #{link_to("Try Again", request.url)}."
end

# Map sudoku numbers to ColorKu colors.  The floats are an artifact of
# another implementation and it's convenient for me to leave them that
# way.  But for this implementation, map them to hex color strings
# "#rrggbb".

COLORS = [[1.00, 0.00, 0.00],  # red
          [1.00, 0.60, 0.00],  # orange
          [1.00, 1.00, 0.00],  # yellow
          [0.20, 0.80, 0.20],  # light green
          [0.00, 0.35, 0.00],  # dark green
          [0.43, 0.71, 0.98],  # light blue
          [0.00, 0.00, 0.80],  # dark blue
          [0.93, 0.51, 0.93],  # lavender
          [0.40, 0.00, 0.51],  # purple
         ].map do |color|
  "#%02x%02x%02x" % color.map{|n| n * 255}
end

# WebSudoku is just some stuff for fetching data from websudoku.com.

module WebSudoku
  LEVELS = {"Easy" => "1", "Medium" => "2", "Hard" => "3", "Evil" => "4"}

  # Fetch a puzzle of the given level from websudoku.com.  Return two
  # strings: the first is digits 1-9, one for each position
  # left-to-right top-to-bottom, the second is digits 0 and 1 for
  # whether the position is part of the setup ("0") or is to be solved
  # for ("1").

  def self.get_puzzle(level, puzzle_number = nil)
    set_id = puzzle_number && "&set_id=#{puzzle_number}"
    page = get_page("http://view.websudoku.com/?level=#{level}#{set_id}")

    extract_puzzle(page)
  end

  def self.extract_puzzle(page)
    # "solved" is the solution

    page =~ %r{cheat='([1-9]*)'}
    solved = $1

    # "editmask" has a "0" for each fixed value

    page =~ %r{<input id="editmask" [^>]* value="([01]*)">}i
    editmask = $1

    if !(solved && editmask)
      raise "Couldn't find the puzzle in the page."
    end

    [solved, editmask]
  end

  def self.get_page(page)
    response = begin
      HTTP.get(page, follow: true)
    rescue => ex
      raise "HTTP problem: #{page}: #{ex.inspect}"
    end

    if response.status_code != 200
      raise "HTTP problem: #{page}: #{response.status}"
    end

    response.to_s
  end
end
