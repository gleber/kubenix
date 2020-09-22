{ pkgsPath # ? <nixpkgs>
, nixosPath ? "${pkgsPath}/nixos"
}:

let
  pkgs = import pkgsPath {
    overlays = [ (self: super: rec {
      kubernetes = builtins.trace "YYY k8s default.nix overlay" (super.kubernetes.overrideAttrs (oa: {
        src = lib.cleanSource /home/gleber/code/kubernetes;
      }));
      kubectl = builtins.trace "YYY default.nix overlay" (super.kubectl.overrideAttrs (oa: {
        src = kubernetes;
      }));
    })];
  };
  lib =  pkgs.lib;
in

with lib;
let
  kubenixLib = import ./lib { inherit lib pkgs; };
  lib' = lib.extend (lib: self: import ./lib/extra.nix { inherit lib pkgs; });

  defaultSpecialArgs = {
    inherit kubenix nixosPath;
  };

  # evalModules with same interface as lib.evalModules and kubenix as
  # special argument
  evalModules = {
    module ? null,
    modules ? [module],
    specialArgs ? defaultSpecialArgs, ...
  }@attrs: let
    attrs' = filterAttrs (n: _: n != "module") attrs;
  in lib'.evalModules (recursiveUpdate {
    inherit specialArgs modules;
    args = {
      inherit pkgs;
      name = "default";
    };
  } attrs');

  modules = import ./modules;

  # legacy support for buildResources
  buildResources = {
    configuration ? {},
    writeJSON ? true,
    writeHash ? true
  }: let
    evaled = evalModules {
      modules = [
        configuration
        modules.legacy
      ];
    };

    generated = evaled.config.kubernetes.generated;

    result =
      if writeJSON
      then pkgs.writeText "resources.json" (builtins.toJSON generated)
      else generated;
  in result;

  kubenix = {
    inherit evalModules buildResources modules;

    lib = kubenixLib;
  };
in kubenix
