output "bookinfo_url" {
  description = "URL to access the Bookinfo sample application through KGateway"
  value       = var.enable_bookinfo ? "https://bookinfo.${var.domain_name}" : null
}

output "bookinfo_kiali_view" {
  description = "Instructions for viewing the Bookinfo application in Kiali"
  value       = var.enable_bookinfo ? "Open Kiali and navigate to 'Graph' view, then select 'bookinfo' namespace to visualize the service mesh" : null
}

output "is_enabled" {
  description = "Whether the Bookinfo application is enabled"
  value       = var.enable_bookinfo
}
