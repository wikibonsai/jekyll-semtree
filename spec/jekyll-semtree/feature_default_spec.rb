# frozen_string_literal: true

require "jekyll-semtree"
require "spec_helper"

RSpec.describe(Jekyll::SemTree::Generator) do
  let(:config) do
    Jekyll.configuration(
      config_overrides.merge(
        "collections"          => {
          "index" => { "output" => true },
          "entries" => { "output" => true },
        },
        "permalink"            => "pretty",
        "skip_config_files"    => false,
        "source"               => fixtures_dir,
        "destination"          => site_dir,
        "url"                  => "garden.testsite.com",
        "testing"              => true,
        # "baseurl"              => "",
      )
    )
  end
  let(:config_overrides)     { {} }
  let(:site)                 { Jekyll::Site.new(config) }

  let(:doc_lvl_0_root)             { find_by_title(site.collections["index"].docs, "Knowledge Bonsai") }
  let(:doc_lvl_1_entry)            { find_by_title(site.collections["entries"].docs, "An Entry") }
  let(:doc_lvl_2_post)             { find_by_title(site.collections["posts"].docs, "A Post") }

  # makes markdown tests work
  subject                    { described_class.new(site.config) }

  before(:each) do
    site.reset
    site.process
  end

  after(:each) do
    # cleanup _site/ dir
    FileUtils.rm_rf(Dir["#{site_dir()}"])
  end

  context "processes markdown" do

    context "detecting markdown" do
      before { subject.instance_variable_set "@site", site }

      it "knows when an extension is markdown" do
        expect(subject.send(:markdown_extension?, ".md")).to eql(true)
      end

      it "knows when an extension isn't markdown" do
        expect(subject.send(:markdown_extension?, ".html")).to eql(false)
      end

      it "knows the markdown converter" do
        expect(subject.send(:markdown_converter)).to be_a(Jekyll::Converters::Markdown)
      end
    end

  end

  context "basic default tree path processing" do

    context "when tree path level exists" do

      context "metadata:" do

        it "'children' is an array of doc urls" do
          expect(doc_lvl_1_entry.data['children']).to be_a(Array)
          expect(doc_lvl_1_entry.data['children']).to eq(["/2023/09/18/post/", "missing"])
        end

        it "'ancestors' is an array of doc urls" do
          expect(doc_lvl_1_entry.data['ancestors']).to be_a(Array)
          expect(doc_lvl_1_entry.data['ancestors']).to eq(["/index/i.bonsai/"])
        end

      end

      context "what each level looks like at:" do

        it "lvl-0 (root) index ('ancestors': 0; 'children': 2; w/ urls)" do
          expect(doc_lvl_0_root.data['ancestors'].size).to eq(0)
          expect(doc_lvl_0_root.data['children'].size).to eq(2)
          expect(doc_lvl_0_root.data['ancestors']).to eq([])
          expect(doc_lvl_0_root.data['children']).to eq(["/entries/an-entry/", "/index/i.another-branch/"])
        end

        it "lvl-1 entry ('ancestors': 1; 'children': 1; w/ urls)" do
          expect(doc_lvl_1_entry.data['ancestors'].size).to eq(1)
          expect(doc_lvl_1_entry.data['ancestors']).to eq(["/index/i.bonsai/"])
          expect(doc_lvl_1_entry.data['children'].size).to eq(2)
          expect(doc_lvl_1_entry.data['children']).to eq(["/2023/09/18/post/", "missing"])
        end

        it "lvl-2 post ('ancestors': 2; 'children': 0; w/ urls)" do
          expect(doc_lvl_2_post.data['ancestors'].size).to eq(2)
          expect(doc_lvl_2_post.data['ancestors']).to eq(["/index/i.bonsai/", "/entries/an-entry/"])
          expect(doc_lvl_2_post.data['children'].size).to eq(0)
          expect(doc_lvl_2_post.data['children']).to eq([])
        end

      end

    end

  end

end
