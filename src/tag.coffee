_      = require 'underscore'
Commit = require './commit'
Actor  = require './actor'
{Ref}  = require './ref'
whn   = require 'when'

module.exports = class Tag extends Ref
  @find_all: (repo) ->
    return Ref.find_all repo, "tag", Tag


  # Public: Get the tag message.
  #
  # Returns String.
  message: () ->
    return @lazy()
      .then (data) ->
        return data.message

  # Public: Get the tag author.
  #
  # Returns Actor.
  tagger: () ->
    return @lazy()
      .then (data) ->
        return data.tagger

  # Public: Get the date that the tag was created.
  #
  # Returns Date.
  tag_date: () ->
    return @lazy()
      .then (data) ->
        return data.tag_date

  # Internal: Load the tag data.
  lazy: () ->
    return whn.promise @_lazy_data if @_lazy_data
    return @repo.git "cat-file", {}, ["tag", @name]
      .then (stdout, stderr) =>
        lines = stdout.split "\n"
        data  = {}

        lines.shift() # object 4ae1cc5e6c7bb85b14ecdf221030c71d0654a42e
        lines.shift() # type commit
        lines.shift() # tag v0.0.2

        # bob <bob@example.com>
        author_line       = lines.shift()
        [m, author, epoch] = /^.+? (.*) (\d+) .*$/.exec author_line

        data.tagger   = Actor.from_string author
        data.tag_date = new Date epoch

        lines.shift()
        message = []
        while line = lines.shift()
          message.push line
        data.message = message.join("\n")

        return (@_lazy_data = data)