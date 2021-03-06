require 'rails_helper'
require 'vcr_setup'

RSpec.describe BookDuetsController, type: :controller do

  # Skip the authentication for testing porpoises
  before(:each) do
    BookDuetsController.skip_before_filter :authenticate
  end

  describe "GET #custom_duet" do
    it "returns 200 if a custom duet build is successful" do
      VCR.use_cassette 'controllers/custom_duet', :record => :new_episodes do
        get :custom_duet, {author: "Neil_Gaiman", musician: "Nickelback", filter_level:"none"}
        expect(response.response_code).to eq(200)
      end
    end

    it "returns a NoAuthorFound error if an author can't be found" do
      VCR.use_cassette 'controllers/author_not_found', :record => :new_episodes do
        get :custom_duet, {author: "Gregory Maguire", musician: "Clint Mansell", filter_level:"none"}
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("AuthorNotFound")
      end
    end

    it "returns a NoLyricsFound error if lyrics can't be found" do
      VCR.use_cassette 'controllers/lyrics_not_found', :record => :new_episodes do
        get :custom_duet, {author: "Neil Gaiman", musician: "asdf", filter_level:"none"}
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("LyricsNotFound")
      end
    end

    it "uses encoding that is friendly to spaces and special characters" do
      VCR.use_cassette "controllers/special_character_support", :record => :new_episodes  do
        get :custom_duet, {author: "Anaïs Nin", musician: "Mötorhead", filter_level:"none"}
        json_response = JSON.parse(response.body)

        expect(json_response["error"]).to be(nil)
      end
    end

    it "standardizes redis artist name keys so that they don't include underscores" do
      VCR.use_cassette 'controllers/custom_duet', :record => :new_episodes do
        get :custom_duet, {author: "Neil_Gaiman", musician: "Nickelback", filter_level:"none"}
        expect($redis.exists("Neil_Gaiman")).to eq(false)
        expect($redis.exists("Neil Gaiman")).to eq(true)
      end
    end
  end

  describe "corpora caching" do

    before(:each) do
      VCR.use_cassette "controllers/redis_caching", :record => :new_episodes  do
        get :custom_duet, {author: "J. M. Barrie", musician: "Feist", filter_level:"none"}
        @cached_lyrical_corpus = $redis["Feist"]
        @cached_literary_corpus = $redis["J. M. Barrie"]
      end
    end

    it "avoids building lyrical_corpus if it is cached in redis" do
      controller.send(:build_corpora, "Feist", "J. M. Barrie")

      expect(@cached_lyrical_corpus).to eq($redis["Feist"])
    end

    it "avoids building literary_corpus if it is cached in redis" do
      controller.send(:build_corpora, "Feist", "J. M. Barrie")

      expect(@cached_literary_corpus).to eq($redis["J. M. Barrie"])
    end

    # Don't think I need these specs and methods, since I'm going to
    # just let the cache fill and auto-expire the oldest entries

    # it "will not persist musician keys in redis" do
    #   expect($redis.ttl("Feist")).to_not eq(-1)
    # end
    #
    # it "will not persist author keys in redis" do
    #   expect($redis.ttl("J. M. Barrie")).to_not eq(-1)
    # end
    #
    # it "caches musician keys for at least 300 seconds (5 min)" do
    #   expect($redis.ttl("Feist")).to be <=(300)
    # end
    #
    # it "caches author keys for at least 300 seconds (5 min)" do
    #   expect($redis.ttl("J. M. Barrie")).to be <=(300)
    # end
  end

  describe "logging corpora build frequency" do

    before(:each) do
      VCR.use_cassette "controllers/build_frequency", :record => :new_episodes  do
        get :custom_duet, {author: "Octavia Butler", musician: "Sleater Kinney", filter_level:"none"}
      end
    end

    it "creates a sorted set entry once a corpus is built" do
      expect($redis.zscore("Musicians Log", "Sleater Kinney")).to eq(1.0)
      expect($redis.zscore("Authors Log", "Octavia Butler")).to eq(1.0)
    end

    it "increments logs after each subsequent build" do
      # Force "expire" these entries so that corpora are rebuilt
      $redis.del("Sleater Kinney")
      $redis.del("Octavia Butler")

      VCR.use_cassette "controllers/build_frequency", :record => :new_episodes  do
        get :custom_duet, {author: "Octavia Butler", musician: "Sleater Kinney", filter_level:"none"}
      end

      expect($redis.zscore("Musicians Log", "Sleater Kinney")).to eq(2.0)
      expect($redis.zscore("Authors Log", "Octavia Butler")).to eq(2.0)
    end
  end

  describe "filter" do
    let(:unfiltered_lyrics) {"If you don't like what I'm saying, get the fuck outta here!"}

    context "language filter - none" do
      it "doesn't sanitize the language" do
        filtered_lyrics = controller.send(:filter, unfiltered_lyrics, "none")

        expect(filtered_lyrics).to eq(unfiltered_lyrics)
      end
    end

    context "language filter - hi" do
      it "sanitizes the language" do
        filtered_lyrics = controller.send(:filter, unfiltered_lyrics, "hi")
        
        expect(filtered_lyrics).to include("$@!#%")
      end
    end
  end
end
