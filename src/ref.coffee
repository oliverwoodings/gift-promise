fs     = require 'fs'
Commit = require './commit'
whn    = require 'when'

exports.Ref = class Ref
  constructor: (@name, @commit) ->
    {@repo} = @commit

  # Public: Get a String representation of the Ref.
  toString: ->
    "#<Ref '#{@name}'>"

  # Internal: Find all refs.
  #
  # options - (optional).
  #
  # Returns Array of Ref.
  @find_all: (repo, type, RefClass) ->
    return repo.git.refs type, {}
      .then (text) ->
        names = []
        ids   = []
        for ref in text.split("\n")
          continue if !ref
          [name, id] = ref.split(' ')
          names.push name
          ids.push id

        return Commit.find_commits repo, ids
          .then (commits) ->
            refs = []
            for name, i in names
              refs.push new RefClass name, commits[i]
            return refs


exports.Head = class Head extends Ref
  @find_all: (repo) ->
    return Ref.find_all repo, "head", Head

  @current: (repo) ->
    dfrd = whn.defer()
    fs.readFile "#{repo.dot_git}/HEAD", (err, data) ->
      return dfrd.reject err if err

      ref = /ref: refs\/heads\/([^\s]+)/.exec data
      # When the current branch check out to a commit, instaed of a branch name.
      return dfrd.reject new Error "Current branch is not a valid branch." if !ref

      [m, branch] = ref
      fs.readFile "#{repo.dot_git}/refs/heads/#{branch}", (err, id) ->
        Commit.find repo, id
          .then (commit) ->
            dfrd.resolve new Head branch, commit