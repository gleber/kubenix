{ config, lib, pkgs, kubenix, ... }:

with lib;

{
  imports = [ kubenix.modules.test ./module.nix ];

  test = {
    name = "nginx-deployment";
    description = "Test testing nginx deployment";

    extraConfiguration = {
      environment.systemPackages = [ pkgs.curl ];
      services.kubernetes.package = pkgs.kubernetes;
      services.kubernetes.apiserver.verbosity = 0;
      services.kubernetes.kubelet.verbosity = 0;
      services.kubernetes.proxy.verbosity = 0;
      services.kubernetes.scheduler.verbosity = 0;
      services.kubernetes.controllerManager.verbosity = 0;
      systemd.services.kube-apiserver.after = [ "postgresql.service" ];
      systemd.services.kube-apiserver.environment.TENMO_HOST = "localhost";
      systemd.services.kube-controller-manager.after = [ "postgresql.service" ];
      systemd.services.kube-controller-manager.environment.TENMO_HOST = "localhost";

      services.postgresql = {
        enable = true;
        package = pkgs.postgresql_12;
        enableTCPIP = true;
        authentication = pkgs.lib.mkOverride 10 ''
          local all all trust
          host all all ::1/128 trust
        '';
        initialScript = pkgs.writeText "backend-initScript" ''
          CREATE ROLE tenmo WITH LOGIN PASSWORD 'tenmo' CREATEDB;
          CREATE DATABASE tenmo;
          GRANT ALL PRIVILEGES ON DATABASE tenmo TO tenmo;
          \connect tenmo tenmo
          \i ${/home/gleber/code/tenmo/database.sql}
        '';
      };
      environment.variables.TENMO_HOST = "localhost";
    };

    # TENMO_HOST = "localhost";
    testScript = ''
      import os

      print("XXXXXXXXXXXx")
      print(os.environ)

      print(kube.execute("env"))
      print(kube.execute("which kubectl"))
      print(kube.execute("kubectl apply -f /dev/null 2>&1"))
      print(kube.execute("TENMO_HOST=localhost kubectl apply -f /dev/null 2>&1"))

      kube.wait_until_succeeds(
          "docker load < ${config.docker.images.nginx.image}"
      )
      kube.wait_until_succeeds(
          "TENMO_HOST=localhost kubectl apply -f ${config.kubernetes.result}"
      )

      kube.succeed("kubectl get deployment | grep -i nginx")
      kube.wait_until_succeeds(
          "kubectl get deployment -o go-template nginx --template={{.status.readyReplicas}} | grep 10"
      )
      kube.wait_until_succeeds(
          "${pkgs.curl}/bin/curl http://nginx.default.svc.cluster.local | grep -i hello "
      )
      print(
          kube.execute(
              "${pkgs.curl}/bin/curl http://nginx.default.svc.cluster.local"
          )
      )
      print(
          kube.execute(
              "pg_dump -U tenmo -d tenmo --no-tablespaces --no-unlogged-table-data --on-conflict-do-nothing --inserts -x -a -t events | egrep '^INSERT INTO' > tenmo.dump.sql"
          )
      )

      kube.copy_from_vm("tenmo.dump.sql", "")
    '';
  };
}
