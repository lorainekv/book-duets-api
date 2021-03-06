require 'rails_helper'
require 'vcr_setup'
require 'literary_corpus'

context "building a literary corpus" do

  describe "collect_random_sections" do
    it "collects quote sections (1.x) and their index numbers from wikiquote" do
      @corpus = LiteraryCorpus.new ("Neil_Gaiman")

      VCR.use_cassette "lib/lit_sections" do
        random_sections = @corpus.send(:collect_random_sections)

        expect(random_sections).to be_an_instance_of(Array)
        expect(random_sections.length).to eq(3)
      end
    end

    it "raises error if author is not found on Wikiquotes" do
      @corpus = LiteraryCorpus.new ("asdf")

      VCR.use_cassette "lib/author_not_found" do
        expect { @corpus.send(:collect_random_sections) }.to raise_error("AuthorNotFound")
      end
    end

    it "raises an error if special characters are missing from an authors name" do
      VCR.use_cassette "lib/special_characters_error" do
        @corpus = LiteraryCorpus.new ("Anais Nin")

        expect { @corpus.send(:collect_random_sections) }.to raise_error("AuthorNotFound")
      end
    end
  end

  before(:each) do
    @corpus = LiteraryCorpus.new ("Neil Gaiman")
  end

  describe "get_lit" do
    it "collects literary quotes in redis" do
      VCR.use_cassette "lib/get_lit", :record => :new_episodes do
        @corpus.send(:get_lit)

        expect($redis["Neil Gaiman"]).to_not be(nil)
        expect($redis["Neil Gaiman"]).to be_an_instance_of(String)
      end
    end
  end

  describe "clean_lit" do
    it "removes unrelated content from the corpus" do
      VCR.use_cassette "lib/clean_lit", :record => :new_episodes do
        @corpus.send(:get_lit)
        @corpus.send(:clean_lit)

        expect($redis["Neil Gaiman"]).to_not include ("<li>")
        expect($redis["Neil Gaiman"]).to_not include ("Chapter")
      end
    end
  end
end
