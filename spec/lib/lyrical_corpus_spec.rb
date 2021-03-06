require 'rails_helper'

context "building a lyrical corpus" do
  describe "collect_tracks" do
    it "retrieves five random tracks for Nickelback" do
      @corpus = LyricalCorpus.new("Nickelback")

      VCR.use_cassette 'lib/random_track_collection' do
        tracks = (@corpus.send(:collect_random_tracks))
        expect(tracks).to be_an_instance_of(Array)
        expect(tracks.length).to be(5)
      end
    end

    it "raises an error if musician tracks aren't found on Musixmatch" do
      @corpus = LyricalCorpus.new("asdf")

      VCR.use_cassette 'lib/no_tracks' do
        expect { @corpus.send(:collect_random_tracks) }.to raise_error("LyricsNotFound")
      end
    end
  end

  before(:each) do
    @corpus = LyricalCorpus.new("Nickelback")
  end

  describe "get_lyrics" do
    it "collects lyrics in redis" do
      VCR.use_cassette 'lib/get_lyrics', :record => :new_episodes do
        @corpus.send(:get_lyrics)
          expect($redis["Nickelback"]).to_not be(nil)
          expect($redis["Nickelback"]).to be_an_instance_of(String)
      end
    end
  end

  describe "clean_lyrics" do
    it "removes non-lyrical content from the corpus" do
      VCR.use_cassette 'lib/clean_lyrics', :record => :new_episodes do
        @corpus.send(:get_lyrics)
        @corpus.send(:clean_lyrics)
          expect($redis["Nickelback"]).to_not include("******* This Lyrics is NOT for Commercial use *******")
          expect($redis["Nickelback"]).to_not include("...")
      end
    end
  end
end
