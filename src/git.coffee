fs     = require 'fs'
whn = require 'when'
{exec, spawn} = require 'child_process'

module.exports = Git = (git_dir, dot_git) ->
  dot_git ||= "#{git_dir}/.git"

  git = (command, options, args) ->
    options ?= {}
    options  = options_to_argv options
    options  = options.join " "
    args    ?= []
    args     = args.join " " if args instanceof Array
    bash     = "#{Git.bin} #{command} #{options} #{args}"
    dfrd     = whn.defer()
    exec bash, {cwd: git_dir, encoding:'binary'}, (err, stdout, stderr) ->
      return dfrd.reject new Error(stderr) if stderr
      return dfrd.reject new Error(stdout) if err and stdout
      return dfrd.reject err if err
      dfrd.resolve stdout
    return dfrd.promise

  # Public: Passthrough for raw git commands
  #
  git.cmd  = (command, options, args) ->
    return git command, options, args

  # Public: stream results of git command
  #
  # This is used for large files that you'd need to stream.
  #
  # returns [outstream, errstream]
  #
  git.streamCmd = (command, options, args) ->
    options ?= {}
    options  = options_to_argv options
    args    ?= []
    allargs = [command].concat(options).concat(args)
    process  = spawn Git.bin, allargs, {cwd: git_dir, encoding: 'binary'}
    return [process.stdout, process.stderr]

  # Public: Get a list of the remote names.
  #
  # callback - Receives `(err, names)`.
  #
  git.list_remotes = () ->
    dfrd = whn.defer()
    fs.readdir "#{dot_git}/refs/remotes", (err, files) ->
      if err
        dfrd.reject(err)
      else
        dfrd.resolve files
    return dfrd.promise


  # Public: Get the ref data string.
  #
  # type     - Such as `remote` or `tag`.
  # callback - Receives `(err, stdout)`.
  #
  git.refs = (type, options) ->
    prefix = "refs/#{type}s/"

    return git "show-ref"
      .then (text) ->
        matches = []
        for line in (text || "").split("\n")
          continue if !line
          [id, name] = line.split(' ')
          if name.substr(0, prefix.length) == prefix
            matches.push "#{name.substr(prefix.length)} #{id}"
        return matches.join("\n")
      .catch (err) ->
        # ignore error code 1: means no match
        return null if err?.code is 1
        throw err

  return git


# Public: The `git` command.
Git.bin = "git"



# Internal: Transform an Object into command line options.
#
# Returns an Array of String option arguments.
Git.options_to_argv = options_to_argv = (options) ->
  argv = []
  for key, val of options
    if key.length == 1
      if val == true
        argv.push "-#{key}"
      else if val == false
        # ignore
      else
        argv.push "-#{key}"
        argv.push val
    else
      if val == true
        argv.push "--#{key}"
      else if val == false
        # ignore
      else
        argv.push "--#{key}=#{val}"
  return argv
