module.exports = class Submodule
  constructor: (@repo, options) ->
    {@id, @name, @mode} = options

  # Public: Get the URL of the submodule.
  #
  # treeish  - String treeish to look up the url within.
  # callback - Receives `(err, url)`.
  #
  url: (treeish) ->
    treeish            ?= "master"

    return Submodule.config @repo, treeish
      .then (config) =>
        return config?[@name].url


  # Internal: Parse the `.gitmodules` file.
  #
  # repo     - A Repo.
  # treeish  - String
  # callback - Receives `(err, config)`, where the config object has
  #            the submodule names as its keys.
  #
  # Examples
  #
  # The following `.gitmodules` file:
  #
  #   [submodule "spoon-knife"]
  #       path = spoon-knife
  #       url = git://github.com/octocat/Spoon-Knife.git
  #
  # would parse to:
  #
  #   { "spoon-knife":
  #     { "path": "spoon-knife"
  #     , "url":  "git://github.com/octocat/Spoon-Knife.git"
  #     }
  #   }
  #
  @config: (repo, treeish) ->
    return repo.tree(treeish).find ".gitmodules"
      .then (blob) ->
        return blob.data()
      .then (data) ->
        conf    = {}
        lines   = data.split "\n"
        current = null
        while lines.length
          line = lines.shift()

          if match = /^\[submodule "(.+)"\]$/.exec line
            current       = match[1]
            conf[current] = {}
          else if match = /^\s+([^\s]+)\s+[=]\s+(.+)$/.exec line
            conf[current][match[1]] = match[2]

        return conf