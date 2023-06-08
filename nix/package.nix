{ pkgs
, lib
, buildPythonPackage
, makePythonPath
, fetchPypi
, pythonAtLeast

, python
, six
, progressbar2
, pytest-runner
, pytest
, bsddb3
, requests
, gunicorn
, gevent
, greenlet

, ...
}:

let
  simplePackage = { name, version, hash ? null, sha256 ? null, extension ? "tar.gz", ... }@rest: buildPythonPackage ({
    pname = name;
    inherit version;

    src = fetchPypi ({
      pname = name;
      inherit version extension;
    } // (if hash != null then { inherit hash; } else { })
    // (if sha256 != null then { inherit sha256; } else { }));
  } // rest);

  flup6 = simplePackage {
    name = "flup6";
    version = "1.1.1";
    hash = "sha256-/QNMaGKjILn4F2oU+pTgXWfVnmE1nDTG2r0NMaJqQIQ=";

    # thread vs _thread issues
    doCheck = false;
  };
in
buildPythonPackage rec {
  name = "filetracker";
  version = "2.1.5";
  format = "pyproject";
  disabled = pythonAtLeast "3.9";

  src = builtins.path {
    path = ./..;
    filter = path: type: builtins.match ".*/nix" path == null;
  };

  # TODO: Fix tests, currently it seems like they some tests expect a filetracker server to be running.
  doCheck = false;

  nativeBuildInputs = [
    pytest
    pytest-runner
  ];

  propagatedBuildInputs = [
    six
    bsddb3
    flup6
    (gunicorn.overrideAttrs (old: {
      propagatedBuildInputs = old.propagatedBuildInputs ++ [ gevent ];
    }))
    gevent
    greenlet
    progressbar2
    requests
  ];

  # This will add the required packages to the PYTHONPATH environment variable so that gunicorn workers loaded by gunicorn work.
  # Normally nix will make a python wrapper that adds the required packages to the python package path, but
  # this doesn't work with gunicorn because it's a separate package with it's own wrappers that won't consider filetracker.
  # This is solved by adding the packages to PYTHONPATH which will be inherited by gunicorn.
  makeWrapperArgs = [
    "--prefix"
    "PYTHONPATH"
    ":"
    "${makePythonPath propagatedBuildInputs}:${builtins.placeholder "out"}/${python.sitePackages}"
  ];

  meta = with pkgs.lib; {
    description = "Filetracker caching file storage";
    homepage = "https://github.com/sio2project/filetracker";
    license = licenses.gpl3;
  };
}
