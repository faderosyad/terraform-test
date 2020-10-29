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

output "lb_ip" {
  value = kubernetes_service.fadeFlask.load_balancer_ingress[0].ip
}