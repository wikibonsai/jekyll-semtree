# frozen_string_literal: true
require "jekyll"

# appending to built-in jekyll site object to pass data to jekyll-d3

module Jekyll

  class Site
    # 'doc_mngr' only necessary if 'jekyll-wikirefs' not installed
    attr_accessor :doc_mngr, :tree
  end

end
