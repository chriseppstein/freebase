#!/usr/bin/env ruby
# (c) Copyright 2007 Chris Eppstein. All Rights Reserved. 
# Usage:
#  ruby albums.rb "The Police"


require "freebase"


# add these methods to the Track class
module Freebase::Mixins::Music
  module Track
    def formatted_length
      "#{self.length.to_i / 60}:#{sprintf("%02i", self.length.to_i % 60)}"
    end
  end
end

def usage
%Q{Usage:
    ruby albums.rb artist_name_in_english
}
end

unless ARGV[0]
  puts usage
  exit 1
end

artist = Freebase::Types::Music::Artist.find(:first,
  :conditions => {
    :name => {:value => ARGV[0], :lang => {:name => "English"}},
    :album => [{
      :fb_object => true,
      :name => {:value => nil, :lang => {:name => "English"}},
      :release_date => nil,
      :track => [{
        :fb_object => true,
        :length => nil,
        :name => {:value => nil, :lang => {:name => "English"}}
      }]
    }]
  }
)

artist.albums.each_with_index do |album, i|
  next unless album # XXX I don't know why I'm getting random nils here.
  puts "#{i+1}) #{album.name} (#{album.release_date || '?'})"
  album.tracks.compact.each_with_index do |track, j|
      puts "\tT#{j+1}. #{track.name || '???'} (#{track.formatted_length})"
  end
end