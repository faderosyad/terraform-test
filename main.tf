provider "kubernetes" {}

# Create deployment for flask app and spawn 2 pods 
resource "kubernetes_deployment" "fadeFlask" {
  metadata {
    name = "scalable-flask"
    labels = {
      App = "ScalableFlaskDeployment"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        App = "flask"
      }
    }
    template {
      metadata {
        labels = {
          App = "flask"
        }
      }
      spec {
        container {
          image = "faderosyad/flask-experiment:latest"
          name  = "flask"

          port {
            container_port = 80
          }

          resources {
            limits {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
}

# Create flask service 
resource "kubernetes_service" "fadeFlask" {
  metadata {
    name = "fadeservice"
  }
  spec {
    selector = {
      App = kubernetes_deployment.fadeFlask.spec.0.template.0.metadata[0].labels.App
    }
    port {
      port        = 80
      target_port = 2323
    }

    type = "LoadBalancer"
  }
}

# Create horizontal pocs scaler
resource "kubernetes_horizontal_pod_autoscaler" "fadeFlask" {
  metadata {
    name = "horizontal-flask-scaler"
  }

  spec {
    min_replicas = 2
    max_replicas = 4

    scale_target_ref {
      kind = "Pod"
      name = "flask"
    }
  }
}

# Create security policy for flask application
# resource "kubernetes_pod_security_policy" "fadeFlask" {
#   metadata {
#     name = "fade-flask-security-policy"
#   }
#   spec {
#     privileged                 = false
#     allow_privilege_escalation = false

#     run_as_user {
#       rule = "MustRunAsNonRoot"
#     }

#     se_linux {
#       rule = "RunAsAny"
#     }

#     supplemental_groups {
#       rule = "MustRunAs"
#       range {
#         min = 1
#         max = 65535
#       }
#     }

#     fs_group {
#       rule = "MustRunAs"
#       range {
#         min = 1
#         max = 65535
#       }
#     }

#     read_only_root_filesystem = true
#   }
# }

# Prometheus for monitoring
resource "kubernetes_stateful_set" "flaskPrometheus" {
  metadata {
    annotations = {
      SomeAnnotation = "foobar"
    }

    labels = {
      k8s-app                           = "prometheus"
      "kubernetes.io/cluster-service"   = "true"
      "addonmanager.kubernetes.io/mode" = "Reconcile"
      version                           = "v2.2.1"
    }

    name = "prometheus"
  }

  spec {
    pod_management_policy  = "Parallel"
    replicas               = 1
    revision_history_limit = 5

    selector {
      match_labels = {
        k8s-app = "prometheus"
      }
    }

    service_name = "prometheus"

    template {
      metadata {
        labels = {
          k8s-app = "prometheus"
        }

        annotations = {}
      }

      spec {
        service_account_name = "prometheus"

        init_container {
          name              = "init-chown-data"
          image             = "busybox:latest"
          image_pull_policy = "IfNotPresent"
          command           = ["chown", "-R", "65534:65534", "/data"]

          volume_mount {
            name       = "prometheus-data"
            mount_path = "/data"
            sub_path   = ""
          }
        }

        container {
          name              = "prometheus-server-configmap-reload"
          image             = "jimmidyson/configmap-reload:v0.1"
          image_pull_policy = "IfNotPresent"

          args = [
            "--volume-dir=/etc/config",
            "--webhook-url=http://localhost:9090/-/reload",
          ]

          volume_mount {
            name       = "config-volume"
            mount_path = "/etc/config"
            read_only  = true
          }

          resources {
            limits {
              cpu    = "10m"
              memory = "10Mi"
            }

            requests {
              cpu    = "10m"
              memory = "10Mi"
            }
          }
        }

        container {
          name              = "prometheus-server"
          image             = "prom/prometheus:v2.2.1"
          image_pull_policy = "IfNotPresent"

          args = [
            "--config.file=/etc/config/prometheus.yml",
            "--storage.tsdb.path=/data",
            "--web.console.libraries=/etc/prometheus/console_libraries",
            "--web.console.templates=/etc/prometheus/consoles",
            "--web.enable-lifecycle",
          ]

          port {
            container_port = 9090
          }

          resources {
            limits {
              cpu    = "200m"
              memory = "1000Mi"
            }

            requests {
              cpu    = "200m"
              memory = "1000Mi"
            }
          }

          volume_mount {
            name       = "config-volume"
            mount_path = "/etc/config"
          }

          volume_mount {
            name       = "prometheus-data"
            mount_path = "/data"
            sub_path   = ""
          }

          readiness_probe {
            http_get {
              path = "/-/ready"
              port = 9090
            }

            initial_delay_seconds = 30
            timeout_seconds       = 30
          }

          liveness_probe {
            http_get {
              path   = "/-/healthy"
              port   = 9090
              scheme = "HTTPS"
            }

            initial_delay_seconds = 30
            timeout_seconds       = 30
          }
        }

        termination_grace_period_seconds = 300

        volume {
          name = "config-volume"

          config_map {
            name = "prometheus-config"
          }
        }
      }
    }

    update_strategy {
      type = "RollingUpdate"

      rolling_update {
        partition = 1
      }
    }

    volume_claim_template {
      metadata {
        name = "prometheus-data"
      }

      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = "standard"

        resources {
          requests = {
            storage = "16Gi"
          }
        }
      }
    }
  }
}

output "lb_ip" {
  value = kubernetes_service.fadeFlask.load_balancer_ingress[0].ip
}