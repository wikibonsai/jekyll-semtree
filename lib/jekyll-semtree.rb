# frozen_string_literal: true
require "jekyll"

require_relative "jekyll-semtree/patch/context"
require_relative "jekyll-semtree/patch/site"
require_relative "jekyll-semtree/tree"
require_relative "jekyll-semtree/version"


module Jekyll
  module SemTree

    class Generator < Jekyll::Generator
      # for testing
      attr_reader :config

      CONVERTER_CLASS = Jekyll::Converters::Markdown
      # config keys
      CONFIG_KEY        = "semtree"
      ENABLED_KEY       = "enabled"
      EXCLUDE_KEY       = "exclude"
      DOCTYPE_KEY       = "doctype"
      PAGE_KEY          = "map"
      ROOT_KEY          = "root"
      VIRTUAL_TRUNK_KEY = "virtual_trunk"

      def initialize(config)
        @config ||= config
      end

      def generate(site)
        return if disabled?

        # setup site
        @site = site
        @context ||= Context.new(site)

        # setup docs (based on configs)
        # unless @site.keys.include('doc_mngr') # may have been installed by jekyll-wikirefs or jekyll-wikilinks already
        #   require_relative "jekyll-semtree/patch/doc_manager"
        #   Jekyll::Hooks.register :site, :post_read do |site|
        #     if !self.disabled?
        #       site.doc_mngr = Jekyll::SemTree::DocManager.new(site)
        #     end
        #   end
        # end

        # setup markdown docs
        docs = []
        docs += site.pages # if !$wiki_conf.exclude?(:pages)
        docs += site.docs_to_write.filter { |d| !self.excluded?(d.type) }
        @md_docs = docs.filter { |doc| self.markdown_extension?(doc.extname) }
        if @md_docs.empty?
          Jekyll.logger.warn("Jekyll-SemTree: No semtree files to process.")
        end

        # tree setup
        # root
        root_doc = @md_docs.detect { |d| d.data['slug'] == self.option_root_name }
        if root_doc.nil?
          Jekyll.logger.error("Jekyll-SemTree: No root doc detected.")
        end
        # trunk / index docs
        index_docs = @site.docs_to_write.filter { |d| d.type.to_s == self.option_doctype_name }
        if index_docs.empty?
          Jekyll.logger.error("Jekyll-SemTree: No trunk (index docs) detected.")
        end
        # tree content hash
        tree_hash = build_tree_hash(@site.collections[self.option_doctype_name])
        if tree_hash.empty?
          Jekyll.logger.error("Jekyll-SemTree: No trunk (index docs) detected.")
        end
        # build tree
        @site.tree = Tree.new(tree_hash, root_doc, option_virtual_trunk)

        # generate metadata
        @site.tree.nodes.each do |n|
          doc = @md_docs.detect { |d| n.text == File.basename(d.basename, File.extname(d.basename)) }
          if !doc.nil?
            n.doc = doc
            ancestorNames, childrenNames = @site.tree.find_doc_ancestors_and_children_metadata(doc)
            doc.data['ancestors'] = fnames_to_urls(ancestorNames)
            doc.data['children'] = fnames_to_urls(childrenNames)
          end
        end
        map_doc = @md_docs.detect { |d| option_page == File.basename(d.basename, File.extname(d.basename)) }
        # root_node = @site.tree.nodes.detect { |n| n.text == @site.tree.root }
        map_doc.data['nodes'] = @site.tree.nodes.map { |n| {
          'text' => n.text,
          'url' => n.url,
          'ancestors' => n.ancestors,
          'children' => n.children,
          }
        }
        dangling_entries = []
        @site.collections['entries'].each do |d|
          fname = File.basename(d.basename, File.extname(d.basename))
          if !@site.tree.in_tree?(fname)
            dangling_entries << fname
          end
        end
        Jekyll.logger.warn("Jekyll-SemTree: entries not listed in the tree: #{dangling_entries}")
      end

      def fnames_to_urls(fnames)
        docs = []
        fnames.each do |fname|
          doc = @md_docs.detect { |d| fname == File.basename(d.basename, File.extname(d.basename)) }
          docs << (doc.nil? ? fname : doc.url)
        end
        return docs
      end

      def build_tree_hash(collection_doc)
        tree_data = {}
        collection_doc.each do |d|
          if d.type.to_s == self.option_doctype_name
            fname = File.basename(d.basename, File.extname(d.basename))
            tree_data[fname] = d.content
          end
        end
        return tree_data
      end

      # config helpers

      def disabled?
        option(ENABLED_KEY) == false
      end

      def excluded?(type)
        return false unless option(EXCLUDE_KEY)
        return option(EXCLUDE_KEY).include?(type.to_s)
      end

      def markdown_extension?(extension)
        markdown_converter.matches(extension)
      end

      def markdown_converter
        @markdown_converter ||= @site.find_converter_instance(CONVERTER_CLASS)
      end

      def option(key)
        @config[CONFIG_KEY] && @config[CONFIG_KEY][key]
      end

      def option_root_name
        return option(ROOT_KEY) ? @config[CONFIG_KEY][ROOT_KEY] : 'i.bonsai'
      end

      def option_doctype_name
        return option(DOCTYPE_KEY) ? @config[CONFIG_KEY][DOCTYPE_KEY] : 'index'
      end

      def option_virtual_trunk
        return option(VIRTUAL_TRUNK_KEY) ? @config[CONFIG_KEY][VIRTUAL_TRUNK_KEY] : false
      end

      def option_page
        return option(PAGE_KEY) ? @config[CONFIG_KEY][PAGE_KEY] : 'map'
      end

    end
  end
end
