_         = require 'underscore'
whn       = require 'when'
Blob      = require './blob'
Submodule = require './submodule'

module.exports = class Tree
  # repo    - A Repo.
  # options - An Object with properties "id", "name", and "mode";
  #           or just a String id.
  constructor: (@repo, options) ->
    if _.isString options
      @id = options
    else
      {@id, @name, @mode} = options


  # Public: Get the children of the tree.
  #
  # callback - Receives `(err, children)`, where children is a list
  #            of Trees, Blobs, and Submodules.
  #
  contents: () ->
    return whn.promise @_contents if @_contents
    return @repo.git "ls-tree", {}, @id
      .then (stdout) =>
        @_contents = []
        for line in stdout.split("\n")
          @_contents.push @content_from_string(line) if line
        return @_contents


  # Public: Get the child blobs.
  #
  # callback - Receives `(err, blobs)`.
  #
  blobs: () ->
    return @contents()
      .then (children) ->
        return _.filter children, (child) ->
          child instanceof Blob


  # Public: Get the child blobs.
  #
  # callback - Receives `(err, trees)`.
  #
  trees: () ->
    return @contents()
      .then (children) ->
        return _.filter children, (child) ->
          child instanceof Tree


  # Public: Find the named object in this tree's contents.
  #
  # callback - Receives `(err, obj)` where obj is Tree, Blob, or null
  #            if not found.
  #
  find: (file) ->
    if /\//.test file
      [dir, rest] = file.split "/", 2
      return @trees()
        .then (_trees) =>
          for tree in _trees
            return tree.find rest if tree.name == dir
    else
      return @contents()
        .then (children) ->
          for child in children
            if child.name == file
              return child


  # Internal: Parse a Blob or Tree from the line.
  #
  # line - String
  #
  # Examples
  #
  #   tree.content_from_string "100644 blob e4ff69dd8f19d770e9731b4bc424ccb695f0b5ad    README.md"
  #   # => #<Blob >
  #
  # Returns Blob, Tree or Submodule.
  content_from_string: (line) ->
    [mode, type, id, name] = line.split /[\t ]+/, 4
    switch type
      when "tree"
        new Tree @repo, {id, name, mode}
      when "blob"
        new Blob @repo, {id, name, mode}
      when "link"
        new Blob @repo, {id, name, mode}
      when "commit"
        new Submodule @repo, {id, name, mode}
      else
        throw new Error "Invalid object type: '#{type}'"

  # Public: Get a String representation of the Tree.
  #
  # Returns String.
  toString: ->
    "#<Tree '#{@id}'>"
