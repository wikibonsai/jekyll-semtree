# frozen_string_literal: true
require "jekyll"

module Jekyll

  class Tree

    OPEN_BRACKETS = '[['
    CLOSE_BRACKETS = ']]'
  
    MARKDOWN_BULLET_ASTERISK = '* '
    MARKDOWN_BULLET_DASH = '- '
    MARKDOWN_BULLET_PLUS = '+ '
  
    REGEX = {
      LEVEL: /^[ \t]*/,  # TODO: link
      TEXT_WITH_LOC: /([^\\:^|\[\]]+)-(\d+)-(\d+)/i,
      TEXT_WITH_ID: /([^\\:^|\[\]]+)-\(([A-Za-z0-9]{5})\)/i,
      WIKITEXT_WITH_ID: /([+*-]) \[\[([^\\:\\^|\[\]]+)-\(([A-Za-z0-9]{5})\)\]\]/i,
      WHITESPACE: /^\s*$/,
    }.freeze

    def is_markdown_bullet(text)
      return [
        MARKDOWN_BULLET_ASTERISK,
        MARKDOWN_BULLET_DASH,
        MARKDOWN_BULLET_PLUS,
      ].include?(text)
    end

    attr_accessor :chunk_size    # size of indentation for each tree level (set by the first indentation found)
    attr_accessor :duplicates    # duplicate node names in the tree
    attr_accessor :level_max     # 
    attr_accessor :nodes         # the tree nodes
    attr_accessor :petiole_map   # a hash where each key is each node in the tree and the value is the index file that contains that node/doc
    attr_accessor :root          # name of the root node/document
    attr_accessor :trunk         # list of index doc fnames
    attr_accessor :virtual_trunk # whether or not the trunk/index documents should be included in the tree data

    def initialize(content, root_doc, virtual_trunk = false)
      # init
      # tree properties
      @chunk_size    = -1
      @level_max     = -1
      @duplicates    = []
      @mkdn_list     = true
      @virtual_trunk = virtual_trunk
      # tree nodes
      @nodes          = []
      @petiole_map   = {}
      @root          = ''
      @trunk         = []

      # go
      root_fname = File.basename(root_doc.basename, File.extname(root_doc.basename))
      # tree_data.each do |data|
      #   if doc != root_doc
      #     # jekyll pages don't have the slug attribute: https://github.com/jekyll/jekyll/blob/master/lib/jekyll/page.rb#L8
      #     if doc.type == :pages
      #       page_basename = File.basename(doc.name, File.extname(doc.name))
      #       doc.data['slug'] = Jekyll::Utils.slugify(page_basename)
      #     end
      #   end
      # end

      # prep
      lines = []
      # single file
      if content.is_a?(String)
        lines = content.split("\n")
        set_units(lines)
        return build_tree('root', { 'root' => lines })
      # multiple files
      elsif content.is_a?(Hash)
        unless root_fname
          puts 'Cannot parse multiple files without a "root" defined'
          return
        end
        unless content.keys.include?(root_fname)
          raise "content hash does not contain: '#{root_fname}'; keys are: #{content.keys.join(', ')}"
        end
        lines = content[root_fname].split("\n")
        set_units(lines)
        content_hash = {}
        content.each do |filename, file_content|
          content_hash[filename] = file_content.split("\n")
        end
        self.clear
        return build_tree(root_fname, deepcopy(content_hash))
      else
        raise "content is not a string or hash: #{content}"
      end
      # print_tree(root)
    end

    def build_tree(cur_key, content, ancestors = [], total_level = 0)
      @trunk = content.keys
      # if the trunk isn't virtual, handle index/trunk file
      unless @virtual_trunk
        node = TreeNode.new(
          cur_key,
          ancestors.map { |n| raw_text(n.text) },
          total_level,
        )
        if total_level == 0
          add_root(cur_key)
        else
          add_branch(cur_key, node.ancestors)
        end
        ancestors << node
        total_level += 1
      end
      # handle file...
      lines = content[cur_key]
      lines.each_with_index do |line, i|
        text = line.gsub(REGEX[:LEVEL], '')
        next if text.nil? || text.empty?
        if @nodes.map(&:text).include?(raw_text(text))
          @duplicates << raw_text(text)
          next
        end
        # calculate numbers
        line_num = i + 1
        level_match = line.match(REGEX[:LEVEL])
        # number of spaces
        next if level_match.nil?
        size = get_whitespace_size(level_match[0])
        level = get_level(size) + total_level
        @chunk_size = 2 if @chunk_size < 0
        # root
        if total_level == 0 && i == 0
          node = TreeNode.new(
            text,
            [],
            level,
            line_num,
          )
          add_root(raw_text(node.text))
          ancestors << node
        # node
        else
          # connect subtree via 'virtual' semantic-tree node
          # TODO: if cur_key == raw_text(text), print a warning: don't do that.
          if cur_key != raw_text(text) && content.keys.include?(raw_text(text))
            # virtual_levels += @chunk_size  # This line is commented out as in the original TypeScript
            ancestors = calc_ancestry(level, ancestors)
            build_tree(raw_text(text), content, deepcopy(ancestors), get_level(size))
            next
          end
          node = TreeNode.new(
            text,
            [],
            level,
            line_num,
          )
          node.text = raw_text(node.text)
          ancestors = calc_ancestry(level, ancestors)
          node.ancestors = ancestors.map { |p| raw_text(p.text) }
          ancestors << node
          add_branch(node.text, node.ancestors, cur_key)
        end
      end
      content.delete(cur_key)
      if content.any? && total_level == 0
        return "Some files were not processed: #{content.keys.join(', ')}"
      end
      if content.empty?
        if @duplicates.any?
          duplicates = @duplicates.uniq
          error_msg = "Tree did not build, duplicate nodes found:\n\n"
          error_msg += duplicates.join(', ') + "\n\n"
          clear
          return error_msg
        end
        return @nodes.dup
      end
    end

    # helper methods

    def add_root(text)
      @root = text
      @nodes << TreeNode.new(text)
      @petiole_map[text] = text
    end

    def add_branch(text, ancestry_titles, trnk_fname = nil)
      trnk_fname ||= text
      ancestry_titles.each_with_index do |ancestry_title, i|
        if i < (ancestry_titles.length - 1)
          node = @nodes.find { |n| n.text == ancestry_title }
          if node && !node.children.include?(ancestry_titles[i + 1])
            node.children << ancestry_titles[i + 1]
          end
        else
          node = @nodes.find { |n| n.text == ancestry_title }
          if node && !node.children.include?(text)
            node.children << text
          end
        end
      end
      @nodes << TreeNode.new(text, ancestry_titles)
      @petiole_map[text] = trnk_fname
    end

    def calc_ancestry(level, ancestors)
      parent = ancestors.last
      is_child = (parent.level == (level - 1))
      is_sibling = (parent.level == level)
      # child:
      # - [[parent]]
      #   - [[child]]
      if is_child
        # continue...
      # sibling:
      # - [[sibling]]
      # - [[sibling]]
      elsif is_sibling
        # we can safely throw away the last node name because
        # it can't have children if we've already decreased the level
        ancestors.pop
      # unrelated (great+) (grand)parent:
      #     - [[descendent]]
      # - [[great-grandparent]]
      else  # (parent.level < level)
        level_diff = parent.level - level
        (1..(level_diff + 1)).each do
          ancestors.pop
        end
      end
      return ancestors
    end

    # util methods

    def raw_text(full_text)
      # strip markdown list marker if it exists
      if @mkdn_list && is_markdown_bullet(full_text[0..1])
        full_text = full_text[2..-1]
      end
      # strip wikistring special chars and line breaks
      # using gsub to replace substrings in Ruby
      full_text.gsub!(OPEN_BRACKETS, '')
      full_text.gsub!(CLOSE_BRACKETS, '')
      full_text.gsub!(/\r?\n|\r/, '')
      return full_text
    end

    def define_level_size(whitespace)
      if whitespace[0] == ' '
        return whitespace.length
      elsif whitespace[0] == "\t"
        tab_size = 4
        return tab_size
      else
        # puts "defineLevelSize: unknown whitespace: #{whitespace}"
        return -1
      end
    end

    def get_whitespace_size(whitespace)
      if whitespace.include?(' ')
        return whitespace.length
      elsif whitespace.include?("\t")
        tab_size = 4
        return whitespace.length * tab_size
      else
        # puts "getWhitespaceSize: unknown whitespace: #{whitespace}"
        return whitespace.length
      end
    end

    def get_level(size)
      (size / @chunk_size) + 1
    end

    def clear
      @root = ''
      @nodes = []
      @petiole_map = {}
      @duplicates = []
    end

    def deepcopy(obj)
      Marshal.load(Marshal.dump(obj))
    end

    def set_units(lines)
      # calculate number of spaces per level and size of deepest level
      lines.each do |line|
        level_match = line.match(REGEX[:LEVEL])
        # calculates number of spaces
        if level_match
          if @chunk_size < 0
            @chunk_size = define_level_size(level_match[0])
          end
          level = get_level(level_match[0].length)
        else
          next
        end
        @level_max = level > @level_max ? level : @level_max
      end
    end

    # metadata methods

    def get_all_lineage_ids(target_node_id, node=@nodes.detect { |n| n.text == @root }, ancestors=[], descendents=[], found=false)
      # found target node, stop adding ancestors and build descendents
      if target_node_id == node.id || target_node_id == node.text || found
        node.children.each do |child|
          child_node = @nodes.detect { |n| n.text == child }
          # if the child document is an empty string, it is a missing node
          if child_node.missing
            descendents << child_node.text
          else
            descendents << child_node.id
          end
          self.get_all_lineage_ids(target_node_id, child_node, ancestors.clone, descendents, found=true)
        end
        return ancestors, descendents
      # target node not yet found, build ancestors
      else
        # if the node document is an empty string, it is a missing node
        if node.missing
          ancestors << node.text
        else
          ancestors << node.id
        end
        results = []
        node.children.each do |child|
          child_node = @nodes.detect { |n| n.text == child }
          results.concat(self.get_all_lineage_ids(target_node_id, child_node, ancestors.clone))
        end
        return results.select { |r| !r.nil? }
      end
    end

    def get_sibling_ids(target_node_id, node=@nodes.detect { |n| n.text == @root }, parent=nil)
      return [] if node.text === @root
      # found target node
      if target_node_id == node.id || target_node_id == node.text
        return parent.children.select { |c| c.id }
      # target node not yet found
      else
        node.children.each do |child|
          child_node = @nodes.detect { |n| n.text == child }
          self.get_sibling_ids(target_node_id, child_node, node)
        end
      end
    end

    # find the parent and children of the 'target_doc'.
    def find_doc_ancestors_and_children_metadata(target_doc)
      fname = File.basename(target_doc.basename, File.extname(target_doc.basename))
      node = @nodes.detect { |n| n.text == fname }
      return node.ancestors, node.children
    end

    def in_tree?(fname)
      return @nodes.map(&:text).include?(fname)
    end

    # ...for debugging

    def to_s
      puts build_tree_str
    end

    def print_nodes
      puts "# Tree Nodes: "
      @nodes.each do |node|
        puts "# #{node.to_s}"
      end
    end

    def build_tree_str(cur_node_name = @root, prefix = '')
      output = "#{cur_node_name}\n"
      node = @nodes.find { |n| n.text == cur_node_name }
      if node.nil?
        puts `SemTree.build_tree_str: error: nil node for name '#{cur_node_name}'`
        return output
      end
      node.children.each_with_index do |child, index|
        is_last_child = index == node.children.length - 1
        child_prefix = prefix + (is_last_child ? '└── ' : '├── ')
        grandchild_prefix = prefix + (is_last_child ? '    ' : '|   ')
        subtree = build_tree_str(child, grandchild_prefix)
        output += "#{child_prefix}#{subtree}"
      end
      return output
    end
  end

  # class TreeNode
  #   attr_accessor :ancestors  # array of strings for the text of each node from root to current (leaf)
  #   attr_accessor :children   # array of strings for the text of each child node
  #   attr_accessor :doc        # the associated jekyll document
  #   attr_accessor :text       # text of the node -- used for primary identification in tree and must be uniquely named
  #   attr_accessor :url        # jekyll blog url for the given node/page

  #   def initialize(text, ancestors=[], children=[], url="", doc="")
  #     @text = text
  #     @ancestors = ancestors
  #     # optional
  #     @children = children
  #     @url = url.nil? ? "" : url
  #     @doc = doc
  #   end

  #   def missing
  #     return @doc == ""
  #   end

  #   def type
  #     return @doc.type
  #   end

  #   def to_s
  #     "<Node text: '#{@text}', ancestors: #{@ancestors}, children: #{@children}"
  #   end
  # end

  class TreeNode
    attr_accessor :id         # node id -- should be unique
    attr_accessor :ancestors  # array of strings for the text of each node from root to current (leaf)
    attr_accessor :children   # array of strings for the text of each child node
    attr_accessor :doc        # the associated jekyll document
    attr_accessor :level      # level in the tree
    attr_accessor :line       # line of the index file content
                              # does not include stripped content (e.g. yaml);
                              # value for index docs is -1
    attr_accessor :text       # text of the node -- used for primary identification in tree and must be uniquely named
    attr_accessor :url        # jekyll blog url for the given node/page

    def initialize(text, ancestors=[], level=-1, line=-1, children=[], doc="")
      # mandatory
      @text = text
      @ancestors = ancestors
      # optional
      @children = children
      @level = level
      @line = line
      @doc = doc
    end

    def missing
      return @doc == ''
      # return (@doc.nil? || (@doc.class == String))
    end

    def to_s
      "<Node text: '#{@text}', ancestors: #{@ancestors}, children: #{@children}"
    end

    # doc properties

    def id
      return (self.missing) ? @text : @doc.url
    end

    def url
      return (self.missing) ? @text : @doc.url
    end

    def title
      return (self.missing) ? @text : @doc.data['title']
    end

    def type
      return (self.missing) ? 'zombie' : @doc.type
    end

    # for legacy 'jekyll-namespaces' calls
    def namespace
      return false
    end
  end
end
