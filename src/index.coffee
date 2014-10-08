{exec} = require 'child_process'
Repo   = require './repo'
whn   = require 'when'

# Public: Create a Repo from the given path.
#
# Returns Repo.
module.exports = Git = (path, bare=false) ->
  return new Repo path, bare


# Public: Initialize a git repository.
#
# path     - The directory to run `git init .` in.
# bare     - Create a bare repository when true.
# callback - Receives `(err, repo)`.
#
Git.init = (path, bare) ->
  if bare
    bash = "git init --bare ."
  else
    bash = "git init ."
  dfrd = whn.defer()
  exec bash, {cwd: path}
  , (err, stdout, stderr) ->
    if (err)
      dfrd.reject(err)
    else
      dfrd.resolve(new Repo path, bare)
  return dfrd.promise

# Public: Clone a git repository.
#
# repository - The repository to clone from.
# path       - The directory to clone into.
# callback   - Receives `(err, repo)`.
#
Git.clone = (repository, path, callback) ->
  bash = "git clone #{repository} #{path}"
  dfrd = whn.defer()
  exec bash, (err, stdout, stderr) ->
    if (err)
      dfrd.reject(err)
    else
      dfrd.resolve(new Repo path)
  return dfrd.promise