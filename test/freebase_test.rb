require 'test/unit'
require File.dirname(__FILE__)+'/test_helper'

class FreebaseTest < Test::Unit::TestCase
  # Replace this with your real tests.
  def test_load_music_artist
    Freebase::Types::Music::Artist
  end
  def test_find_first_artist
    assert_kind_of Freebase::Types::Music::Artist,
                   (artist = Freebase::Types::Music::Artist.find(:first,:conditions => {:name => "The Police"}))
    assert_equal 20, artist.albums.size
  end
  def test_association_preloading
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
    quiesce(:find, :reload) do
      assert_equal 14, artist.albums.size
      assert_equal 8, artist.albums.first.tracks.size
      #artist.albums.first.producer
    end
  end
end
