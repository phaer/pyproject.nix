{ pep518, pep621, poetry, ... }:

{
  /* Load dependencies from a pyproject.toml.

     Type: loadPyproject :: AttrSet -> AttrSet

     Example:
       # loadPyproject { pyproject = lib.importTOML }
       {
         dependencies = { }; # Parsed dependency structure in the schema of `lib.pep621.parseDependencies`
         build-systems = [ ];  # Returned by `lib.pep518.parseBuildSystems`
         pyproject = { }; # The unmarshaled contents of pyproject.toml
       }
  */
  loadPyproject =
    {
      # The unmarshaled contents of pyproject.toml
      pyproject
      # Example: extrasAttrPaths = [ "tool.pdm.dev-dependencies" ];
    , extrasAttrPaths ? [ ]
    }: {
      dependencies = pep621.parseDependencies { inherit pyproject extrasAttrPaths; };
      build-systems = pep518.parseBuildSystems pyproject;
      inherit pyproject;
    };

  /* Load dependencies from a Poetry pyproject.toml.

     Type: loadPoetryPyproject :: AttrSet -> AttrSet

     Example:
       # loadPoetryPyproject { pyproject = lib.importTOML }
       {
         dependencies = { }; # Parsed dependency structure in the schema of `lib.pep621.parseDependencies`
         build-systems = [ ];  # Returned by `lib.pep518.parseBuildSystems`
         pyproject = { }; # The unmarshaled contents of pyproject.toml
       }
  */
  loadPoetryPyproject =
    {
      # The unmarshaled contents of pyproject.toml
      pyproject
    }:
    let
      pyproject-pep621 = poetry.translatePoetryProject pyproject;
    in
    {
      dependencies = poetry.parseDependencies pyproject;
      build-systems = pep518.parseBuildSystems pyproject;
      pyproject = pyproject-pep621;
      pyproject-poetry = pyproject;
    };

}
