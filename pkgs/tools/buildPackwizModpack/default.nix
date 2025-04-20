{
  lib,
  stdenvNoCC,
  fetchurl,
  jre_headless,
  jq,
  moreutils,
  curl,
  cacert,
  packwiz,
}:
lib.makeOverridable (
  {
    pname ? "packwiz-pack",
    version ? "",
    src,
    packHash ? "",
    # Either 'server' or 'both' (to get client mods as well)
    side ? "server",
    ...
  }@args:
  assert (side == "server") || (side == "both");
  stdenvNoCC.mkDerivation (
    finalAttrs:
    {
      inherit pname version src;

      packwizInstaller = fetchurl rec {
        pname = "packwiz-installer";
        version = "0.5.8";
        url = "https://github.com/packwiz/${pname}/releases/download/v${version}/${pname}.jar";
        hash = "sha256-+sFi4ODZoMQGsZ8xOGZRir3a0oQWXjmRTGlzcXO/gPc=";
      };

      packwizInstallerBootstrap = fetchurl rec {
        pname = "packwiz-installer-bootstrap";
        version = "0.0.3";
        url = "https://github.com/packwiz/${pname}/releases/download/v${version}/${pname}.jar";
        hash = "sha256-qPuyTcYEJ46X9GiOgtPZGjGLmO/AjV2/y8vKtkQ9EWw=";
      };

      buildInputs = [
        packwiz
        jre_headless
        jq
        moreutils
        curl
        cacert
      ];

      buildPhase = ''
        runHook preBuild
        touch index.toml
        packwiz refresh
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        mkdir -p $out
        cp -frv * $out

        pushd $out

        java -jar "$packwizInstallerBootstrap" \
        "pack.toml" \
        --bootstrap-main-jar "$packwizInstaller" \
        --bootstrap-no-update \
        --no-gui \
        --side ${side}

        # fix nondeterminism
        rm -frv env-vars
        jq -Sc '.' packwiz.json | sponge packwiz.json

        popd

        runHook postInstall
      '';

      passthru.manifest = "${finalAttrs.src}/pack.toml";
      dontFixup = true;

      outputHashMode = "recursive";
      outputHashAlgo = "sha256";
      outputHash = packHash;
    }
    // args
  )
)
