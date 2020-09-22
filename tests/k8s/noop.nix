{ config, lib, pkgs, kubenix, images, k8sVersion, ... }:

with lib;

let
  cfg = config.kubernetes.api.resources.pods.nginx;
in {
  imports = [ kubenix.modules.test kubenix.modules.k8s kubenix.modules.docker ];

  test = {
    name = "k8s-noop";
    description = "Simple k8s testing a simple deployment";
    assertions = [];
    extraConfiguration = {
      environment.systemPackages = [ pkgs.curl ];
      services.kubernetes.addons.dns.enable = true;
    };
    testScript = ''
      kube.wait_until_succeeds("kubectl get nodes | grep Ready")
      print("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
      print(kube.execute("kubectl cluster-info"))
      print(kube.execute("kubectl get all --all-namespaces"))
      # kube.wait_until_succeeds(
      #     "kubectl get deployment -o go-template nginx --template={{.status.readyReplicas}} | grep 10"
      # )

      # kube.wait_until_succeeds("curl http://nginx.default.svc.cluster.local | grep -i hello")
    '';
  };

  # docker.images.nginx.image = image;

  kubernetes.version = k8sVersion;
  kubernetes.resources.pods.nginx = {};


  # kubernetes.resources.deployments.nginx = {
  #   spec = {
  #     replicas = 10;
  #     selector.matchLabels.app = "nginx";
  #     template.metadata.labels.app = "nginx";
  #     template.spec = {
  #       containers.nginx = {
  #         image = config.docker.images.nginx.path;
  #         imagePullPolicy = "Never";
  #       };
  #     };
  #   };
  # };

  # kubernetes.resources.services.nginx = {
  #   spec = {
  #     ports = [{
  #       name = "http";
  #       port = 80;
  #     }];
  #     selector.app = "nginx";
  #   };
  # };
}
