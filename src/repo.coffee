_      = require 'underscore'
whn    = require 'when'
cmd    = require './git'
Actor  = require './actor'
Commit = require './commit'
Config = require './config'
Tree   = require './tree'
Diff   = require './diff'
Tag    = require './tag'
Status = require './status'

{Ref, Head} = require './ref'

module.exports = class Repo
  constructor: (@path, @bare) ->
    if @bare
      @dot_git = @path
    else
      @dot_git = "#{@path}/.git"
    @git  = cmd @path, @dot_git


  # Public: Get the commit identity for this repository.
  #
  # callback - Receives `(err, actor)`, where `actor` is an Actor.
  #
  identity: () ->
    # git config user.email
    @git "config", {}, ["user.email"]
      .then (stdout = '') =>
        email = stdout?.trim()
        # git config user.name
        return @git "config", {}, ["user.name"]
          .then (stdout = '') =>
            name = stdout?.trim()
            return new Actor name, email


  # Public: Set your account's default identity for commits.
  #
  # actor    - An instance of Actor.
  # callback - Receives `(err)`.
  #
  identify: (actor) ->
    # git config user.email "you@example.com"
    return whn.join @git("config", {}, ["user.email", "\"#{actor.email}\""])
    , @git("config", {}, ["user.name", "\"#{actor.name}\""])


  # Public: Get a list of commits.
  #
  # treeish  - String  (optional).
  # limit    - Integer (optional).
  # skip     - Integer (optional).
  # callback - Function which receives `(err, commits)`, where `commits` is
  #            an Array of Commits.
  #
  # Examples
  #
  #   # Get the 10 most recent commits to master.
  #   repo.commits (err, commits) ->
  #
  #   # Or to a different tag or branch.
  #   repo.commits "v0.0.3", (err, commits) ->
  #
  #   # Limit the maximum number of commits returned.
  #   repo.commits "master", 30, (err, commits) ->
  #
  #   # Skip some (for pagination):
  #   repo.commits "master", 30, 30, (err, commits) ->
  #
  #   # Do not limit commits amount
  #   repo.commits "master", -1, (err, commits) ->
  #
  commits: (start, limit, skip) ->
    start ?= "master"
    limit ?= 10
    skip  ?= 0
    options = {skip}

    if limit != -1
      options["max-count"] = limit

    return Commit.find_all this, start, options


  # Internal: Returns current commit id
  #
  # callback - Receives `(err, id)`.
  #
  current_commit_id: () ->
    return @git "rev-parse HEAD", {}, []
      .then (stdout) ->
        return _.first stdout.split "\n"


  # Public:
  #
  # callback - Receives `(err, commit)`
  #
  current_commit: () ->
    return @current_commit_id()
      .then Commit.find.bind(Commit, this)


  # Public: The tree object for the treeish or master.
  #
  # treeish - String treeish (such as a branch or tag) (optional).
  #
  # Returns Tree.
  tree: (treeish="master") ->
    return new Tree this, treeish


  # Public: Get the difference between the trees.
  #
  # commitA  - A Commit or String commit id.
  # commitB  - A Commit or String commit id.
  # paths    - A list of String paths to restrict the difference to (optional).
  # options  - An object of options to pass to git diff (optional)
  # callback - A Function which receives `(err, diffs)`.
  #
  # Possible forms of the method:
  #
  # diff(commitA, commitB, callback)
  # diff(commitA, commitB, paths, callback)
  # diff(commitA, commitB, options, callback)
  # diff(commitA, commitB, paths, options, callback)
  #
  diff: (commitA, commitB) ->
    [paths, options] = [[], {}]
    if arguments.length is 3
      if arguments[2] instanceof Array
        paths = arguments[2]
      else if arguments[2] instanceof Object
        options = arguments[2]
    else if arguments.length is 4
      paths = arguments[2]
      options = arguments[3]

    commitA = commitA.id if _.isObject(commitA)
    commitB = commitB.id if _.isObject(commitB)
    return @git "diff", options, _.flatten([commitA, commitB, "--", paths])
      .then (stdout) ->
        if _.has(options, 'raw')
          return Diff.parse_raw(this, stdout)
        else
          return Diff.parse(this, stdout)


  # Public: Get the repository's remotes.
  #
  # callback - Receives `(err, remotes)`.
  #
  remotes: () ->
    return Ref.find_all this, "remote", Ref

  # Public: List the repository's remotes.
  #
  # callback - Receives `(err, names)`.
  #
  remote_list: () ->
    return @git.list_remotes()

  # Public: Add a remote.
  #
  # name     - String name of the remote.
  # url      - String url of the remote.
  # callback - Receives `(err)`
  #
  remote_add: (name, url) ->
    return @git "remote", {}, ["add", name, url]

  # Public: Remove a remote.
  #
  # name     - String name of the remote.
  # callback - Receives `(err)`
  #
  remote_remove: (name) ->
    return @git "remote", {}, ["rm", name]

  # Public: `git fetch <name>`.
  #
  # name     - String name of the remote
  # callback - Receives `(err)`.
  #
  remote_fetch: (name) ->
    return @git "fetch", {}, name

  # Public: `git push <name>`.
  #
  # name     - String name of the remote
  # branch   - (optional) Branch to push
  # callback - Receives `(err)`.
  #
  remote_push: (name, branch) ->
    if !branch
      args = name
    else
      args = [name, branch]

    return @git "push", {}, args

  # Public: `git merge <name>`.
  #
  # name     - String name of the source
  # callback - Receives `(err)`.
  #
  merge: (name) ->
    return @git "merge", {}, name

  # Public: Get the repository's status (`git status`).
  #
  # callback - Receives `(err, status)`
  #
  status: () ->
    return Status this

  # Public: Show information about files in the index and the
  #         working tree.
  #
  # options  - An Object of command line arguments to pass to
  #            `git ls-files` (optional).
  # callback - Receives `(err,stdout)`.
  #
  ls_files: (options) ->
    return @git "ls-files", options
      .then (stdout) =>
        return @parse_lsFiles stdout,options


  config: () ->
    return Config this


  # Public: Get the repository's tags.
  #
  # callback - Receives `(err, tags)`.
  #
  tags: () ->
    return Tag.find_all this

  # Public: Create a tag.
  #
  # name     - String
  # options  - An Object of command line arguments to pass to
  #            `git tag` (optional).
  # callback - Receives `(err)`.
  #
  create_tag: (name, options) ->
    return @git "tag", options, [name]

  # Public: Delete the tag.
  #
  # name     - String
  # callback - Receives `(err)`.
  #
  delete_tag: (name) ->
    return @git "tag", {d: name}


  # Public: Get a list of branches.
  #
  # callback - Receives `(err, heads)`.
  #
  branches: () ->
    return Head.find_all this

  # Public: Create a branch with the given name.
  #
  # name     - String name of the new branch.
  # callback - Receives `(err)`.
  #
  create_branch: (name) ->
    return @git "branch", {}, name

  # Public: Delete the branch with the given name.
  #
  # name     - String name of the branch to delete.
  # callback - Receives `(err)`.
  #
  delete_branch: (name) ->
    return @git "branch", {d: true}, name

  # Public: Get the Branch with the given name.
  #
  # name     - String (optional). By default, get the current branch.
  # callback - Receives `(err, head)`
  #
  branch: (name) ->
    if !name
      return Head.current this
    else
      return @branches()
        .then (heads) ->
          for head in heads
            return head if head.name == name
          throw new Error "No branch named '#{name}' found"


  # Public: Checkout the treeish.
  checkout: (treeish) ->
    return @git "checkout", {}, treeish

  # Public: Reset the git repo.
  #
  # treeish  - The {String} to reset to.
  # options  - The {Object} containing one of the following items:
  #   :soft  - {Boolean)
  #   :mixed - {Boolean) When no other option given git defaults to 'mixed'.
  #   :hard  - {Boolean)
  #   :merge - {Boolean)
  #   :keep  - {Boolean)
  # callback - The {Function} to callback.
  #
  reset: (treeish, options) ->
    [treeish, options]  = [options, treeish]  if typeof treeish is 'object'
    treeish ?= 'HEAD'
    options ?= {}

    return @git "reset", options, treeish

  # Public: Checkout file(s) to the index
  #
  # files    - Array of String paths; or a String path. If you want to
  #            checkout all files pass '.'.'
  # options  - Object (optional).
  #            "force" - Boolean
  # callback - Receives `(err)`.
  #
  checkoutFile: (files, options) ->
    [files, options]    = [options, files]    if typeof files is 'object'
    options ?= {}
    files ?= '.'
    files = [files] if _.isString files
    return @git "checkout", options, _.flatten(['--', files])

  # Public: Commit some code.
  #
  # message  - String
  # options  - Object (optional).
  #            "amend" - Boolean
  #            "all"   - Boolean
  #            "author"- String formated like: A U Thor <author@example.com>
  # callback - Receives `(err)`.
  #
  commit: (message, options) ->
    options ?= {}
    options = _.extend options, {m: "\"#{message}\""}
    # add quotes around author
    options.author = "\"#{options.author}\"" if options.author?
    return @git "commit", options

  # Public: Add files to the index.
  #
  # files    - Array of String paths; or a String path.
  # options  - Object (optional).
  #            "all"   - Boolean
  # callback - Receives `(err)`.
  #
  add: (files, options) ->
    options ?= {}
    files = [files] if _.isString files
    return @git "add", options, files

  # Public: Remove files from the index.
  #
  # files    - Array of String paths; or a String path.
  # options  - Object (optional).
  #            "recursive" - Boolean
  # callback - Receives `(err)`.
  #
  remove: (files, options) ->
    options ?= {}
    files = [files] if _.isString files
    return @git "rm", options, files

  # Public: Revert the given commit.
  revert: (sha) ->
    return @git "revert", {}, sha


  # Public: Sync the current branch with the remote.
  #
  # Arguments: ([[remote_name, ]branch_name, ]callback)
  #
  # remote_name - String (optional).
  # branch_name - String.
  # callback - Receives `(stderr)`.
  #
  sync: (remote_name, branch_name) ->

    # handle 'curried' arguments
    [remote, branch] = [remote_name, branch_name]
    [remote, branch] = ["origin", remote_name] if !branch_name
    [remote, branch] = ["origin", "master"]    if !remote_name
    status = null
    return @status()
      .then (sts) =>
        status = sts
        return @git "stash", {}, ["save", "-u"]
      .then () =>
        return @git "pull", {}, [remote, branch]
      .then () =>
        return @git "push", {}, [remote, branc4h]
      .then () =>
        return @git "stash", {}, ["pop"] if not status?.clean

  # Public: Pull the remotes from the master.
  #
  # Arguments: ([[remote_name, ]branch_name, ]callback)
  #
  # remote_name - String (optional).
  # branch_name - String.
  # callback - Receives `(stderr)`.
  #
  pull: (remote_name, branch_name) ->

    # handle 'curried' arguments
    [remote, branch] = [remote_name, branch_name]
    [remote, branch] = ["origin", remote_name] if !branch_name
    [remote, branch] = ["origin", "master"]    if !remote_name

    return @status()
      .then (status) =>
        return @git "pull", {}, [remote, branch]

  # Internal: Parse the list of files from `git ls-files`
  #
  # Return Files[]
  parse_lsFiles: (text,options) ->
    files = []
    if _.has(options,'z')
      lines   = text.split "\0"
    else
    	lines   = text.split "\n"
    while lines.length
      line =  lines.shift().split(" ")
      files.push line
      while lines[0]? && !lines[0].length
        lines.shift()

    return files
