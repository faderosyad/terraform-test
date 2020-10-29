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
