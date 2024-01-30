{ lib
, pep440
, pep508
, pep621
, pypa
, ...
}:
lib.fix (self:
let
  inherit (builtins) attrValues foldl' filter;
  inherit (lib) flatten;

in
{
  checks.version = { python }: dependency:
    let
      pname = pypa.normalizePackageName dependency.name;
      pversion = python.pkgs.${pname}.version;
      version = pep440.parseVersion python.pkgs.${pname}.version;
      incompatible = filter (cond: ! pep440.comparators.${cond.op} version cond.version) dependency.conditions;
    in
    if incompatible == [ ]
    then dependency
    else dependency // {
      validationFailures = {
        version = {
          name = pname;
          version = pversion;
          conditions = incompatible;
        };
      };
    };


  validateChecks =
    {
      # Project metadata as returned by `lib.project.loadPyproject`
      project
    , # Python derivation
      python
    , # Python extras (optionals) to enable
      extras ? [ ]
    , # checks
      checks ? (lib.attrValues self.checks)
    }:
    let
      filteredDeps = pep621.filterDependencies {
        inherit (project) dependencies;
        environ = pep508.mkEnviron python;
        inherit extras;
      };
      checks' = map (fn: fn { inherit python; }) checks;
      dependencies = filteredDeps.dependencies ++ flatten (attrValues filteredDeps.extras) ++ filteredDeps.build-systems;
      checked = map (dep: lib.pipe dep checks') dependencies;
    in
    filter (d: d ? validationFailures) checked;

  /*
    Validates the Python package set held by Python (`python.pkgs`) against the parsed project.

    Returns an attribute set where the name is the Python package derivation `pname` and the value is a list of the mismatching conditions.

    Type: validateVersionConstraints :: AttrSet -> AttrSet

    Example:
      # validateVersionConstraints (lib.project.loadPyproject { ... })
      {
        resolvelib = {
          # conditions as returned by `lib.pep440.parseVersionCond`
          conditions = [ { op = ">="; version = { dev = null; epoch = 0; local = null; post = null; pre = null; release = [ 1 0 1 ]; }; } ];
          # Version from Python package set
          version = "0.5.5";
        };
        unearth = {
          conditions = [ { op = ">="; version = { dev = null; epoch = 0; local = null; post = null; pre = null; release = [ 0 10 0 ]; }; } ];
          version = "0.9.1";
        };
      }
    */
  validateVersionConstraints =
    {
      # Project metadata as returned by `lib.project.loadPyproject`
      project
    , # Python derivation
      python
    , # Python extras (optionals) to enable
      extras ? [ ]
    ,
    }:
    let
      filteredDeps = pep621.filterDependencies {
        inherit (project) dependencies;
        environ = pep508.mkEnviron python;
        inherit extras;
      };
      dependencies = filteredDeps.dependencies ++ flatten (attrValues filteredDeps.extras) ++ filteredDeps.build-systems;
      validator = self.checks.version { inherit python; };
    in
    foldl'
      (acc: dep:
      let
        failure = (validator dep).validationFailures.version or { };
      in
      if failure == { } then acc else acc // {
        ${failure.name} = {
          inherit (failure) version conditions;
        };
      })
      { }
      flatDeps;
})
