{ mkDerivation, aeson, async, base, bytestring, containers
, directory, filepath, http-media, http-types, lens, lib, mtl
, optparse-generic, safe-exceptions, servant, servant-client
, servant-multipart, servant-server, stm, text, time, toml-parser
, transformers, unliftio, utf8-string, wai, wai-extra, warp, zip
, zlib
}:
mkDerivation {
  pname = "relago-server";
  version = "0.1.0.0";
  src = ./server/.;
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [
    aeson async base bytestring containers directory filepath
    http-media http-types lens mtl optparse-generic safe-exceptions
    servant servant-client servant-multipart servant-server stm text
    time toml-parser transformers unliftio utf8-string wai wai-extra
    warp zip zlib
  ];
  executableHaskellDepends = [ base ];
  testHaskellDepends = [ base ];
  homepage = "https://github.com/xinux-org/relago-support";
  license = lib.licensesSpdx."AGPL-3.0-or-later";
  mainProgram = "relago-server";
}
