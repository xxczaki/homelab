# Grafana-managed alert rules.
#
# These were previously PrometheusRule CRDs synced into the Mimir ruler by
# Alloy (apps/alerting-rules). Mimir-managed alerts route to the cloud
# Alertmanager, which has no notification config, so they never reached
# OnCall. Defining them as Grafana-managed rules routes them through the
# Grafana Alertmanager -> notification policy -> Grafana OnCall / Discord.

locals {
  # Cloud Prometheus (Mimir) data source the rules query against.
  prom_ds_uid = "grafanacloud-prom"
}

resource "grafana_folder" "cluster_alerts" {
  title = "Cluster Alerts"
}

# A reusable instant PromQL query (ref A) -> reduce last (ref B) -> threshold
# (ref C). The alert condition is always ref C.
#
# Each rule below keeps the original PromQL but moves the firing comparison out
# of the query and into the threshold expression, so $values.B.Value still
# exposes the underlying metric value for annotations.

resource "grafana_rule_group" "pod_health" {
  name             = "pod-health"
  folder_uid       = grafana_folder.cluster_alerts.uid
  interval_seconds = 60

  rule {
    name      = "PodCrashLoopBackOff"
    condition = "C"
    for       = "5m"

    data {
      ref_id         = "A"
      datasource_uid = local.prom_ds_uid
      relative_time_range {
        from = 600
        to   = 0
      }
      model = jsonencode({
        refId         = "A"
        datasource    = { type = "prometheus", uid = local.prom_ds_uid }
        expr          = "kube_pod_container_status_waiting_reason{reason=\"CrashLoopBackOff\"}"
        instant       = true
        range         = false
        intervalMs    = 1000
        maxDataPoints = 43200
      })
    }
    data {
      ref_id         = "B"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        refId      = "B"
        type       = "reduce"
        expression = "A"
        reducer    = "last"
        datasource = { type = "__expr__", uid = "__expr__" }
      })
    }
    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        refId      = "C"
        type       = "threshold"
        expression = "B"
        datasource = { type = "__expr__", uid = "__expr__" }
        conditions = [{ evaluator = { type = "gt", params = [0] } }]
      })
    }

    labels         = { severity = "critical" }
    annotations    = { summary = "Pod {{ $labels.namespace }}/{{ $labels.pod }} is in CrashLoopBackOff" }
    no_data_state  = "OK"
    exec_err_state = "Error"
  }

  rule {
    name      = "PodHighRestartRate"
    condition = "C"
    for       = "10m"

    data {
      ref_id         = "A"
      datasource_uid = local.prom_ds_uid
      relative_time_range {
        from = 3600
        to   = 0
      }
      model = jsonencode({
        refId         = "A"
        datasource    = { type = "prometheus", uid = local.prom_ds_uid }
        expr          = "count by (namespace) (increase(kube_pod_container_status_restarts_total[1h]) > 5)"
        instant       = true
        range         = false
        intervalMs    = 1000
        maxDataPoints = 43200
      })
    }
    data {
      ref_id         = "B"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        refId      = "B"
        type       = "reduce"
        expression = "A"
        reducer    = "last"
        datasource = { type = "__expr__", uid = "__expr__" }
      })
    }
    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        refId      = "C"
        type       = "threshold"
        expression = "B"
        datasource = { type = "__expr__", uid = "__expr__" }
        conditions = [{ evaluator = { type = "gt", params = [0] } }]
      })
    }

    labels         = { severity = "warning" }
    annotations    = { summary = "{{ humanize $values.B.Value }} pod(s) in namespace {{ $labels.namespace }} restarted more than 5 times in the last hour" }
    no_data_state  = "OK"
    exec_err_state = "Error"
  }

  rule {
    name      = "PodNotReady"
    condition = "C"
    for       = "15m"

    data {
      ref_id         = "A"
      datasource_uid = local.prom_ds_uid
      relative_time_range {
        from = 900
        to   = 0
      }
      model = jsonencode({
        refId         = "A"
        datasource    = { type = "prometheus", uid = local.prom_ds_uid }
        expr          = "min_over_time(kube_pod_status_ready{condition=\"true\"}[15m])"
        instant       = true
        range         = false
        intervalMs    = 1000
        maxDataPoints = 43200
      })
    }
    data {
      ref_id         = "B"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        refId      = "B"
        type       = "reduce"
        expression = "A"
        reducer    = "last"
        datasource = { type = "__expr__", uid = "__expr__" }
      })
    }
    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        refId      = "C"
        type       = "threshold"
        expression = "B"
        datasource = { type = "__expr__", uid = "__expr__" }
        conditions = [{ evaluator = { type = "lt", params = [1] } }]
      })
    }

    labels         = { severity = "warning" }
    annotations    = { summary = "Pod {{ $labels.namespace }}/{{ $labels.pod }} has not been ready for 15m" }
    no_data_state  = "OK"
    exec_err_state = "Error"
  }

  rule {
    name      = "PodPending"
    condition = "C"
    for       = "15m"

    data {
      ref_id         = "A"
      datasource_uid = local.prom_ds_uid
      relative_time_range {
        from = 600
        to   = 0
      }
      model = jsonencode({
        refId         = "A"
        datasource    = { type = "prometheus", uid = local.prom_ds_uid }
        expr          = "kube_pod_status_phase{phase=\"Pending\"}"
        instant       = true
        range         = false
        intervalMs    = 1000
        maxDataPoints = 43200
      })
    }
    data {
      ref_id         = "B"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        refId      = "B"
        type       = "reduce"
        expression = "A"
        reducer    = "last"
        datasource = { type = "__expr__", uid = "__expr__" }
      })
    }
    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        refId      = "C"
        type       = "threshold"
        expression = "B"
        datasource = { type = "__expr__", uid = "__expr__" }
        conditions = [{ evaluator = { type = "gt", params = [0] } }]
      })
    }

    labels         = { severity = "warning" }
    annotations    = { summary = "Pod {{ $labels.namespace }}/{{ $labels.pod }} stuck in Pending" }
    no_data_state  = "OK"
    exec_err_state = "Error"
  }
}

resource "grafana_rule_group" "node_health" {
  name             = "node-health"
  folder_uid       = grafana_folder.cluster_alerts.uid
  interval_seconds = 60

  rule {
    name      = "NodeNotReady"
    condition = "C"
    for       = "5m"

    data {
      ref_id         = "A"
      datasource_uid = local.prom_ds_uid
      relative_time_range {
        from = 600
        to   = 0
      }
      model = jsonencode({
        refId         = "A"
        datasource    = { type = "prometheus", uid = local.prom_ds_uid }
        expr          = "kube_node_status_condition{condition=\"Ready\",status=\"true\"}"
        instant       = true
        range         = false
        intervalMs    = 1000
        maxDataPoints = 43200
      })
    }
    data {
      ref_id         = "B"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        refId      = "B"
        type       = "reduce"
        expression = "A"
        reducer    = "last"
        datasource = { type = "__expr__", uid = "__expr__" }
      })
    }
    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        refId      = "C"
        type       = "threshold"
        expression = "B"
        datasource = { type = "__expr__", uid = "__expr__" }
        conditions = [{ evaluator = { type = "lt", params = [1] } }]
      })
    }

    labels         = { severity = "critical" }
    annotations    = { summary = "Node {{ $labels.node }} is not ready" }
    no_data_state  = "OK"
    exec_err_state = "Error"
  }

  rule {
    name      = "NodeHighCpuUsage"
    condition = "C"
    for       = "15m"

    data {
      ref_id         = "A"
      datasource_uid = local.prom_ds_uid
      relative_time_range {
        from = 600
        to   = 0
      }
      model = jsonencode({
        refId         = "A"
        datasource    = { type = "prometheus", uid = local.prom_ds_uid }
        expr          = "(1 - avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m]))) * 100"
        instant       = true
        range         = false
        intervalMs    = 1000
        maxDataPoints = 43200
      })
    }
    data {
      ref_id         = "B"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        refId      = "B"
        type       = "reduce"
        expression = "A"
        reducer    = "last"
        datasource = { type = "__expr__", uid = "__expr__" }
      })
    }
    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        refId      = "C"
        type       = "threshold"
        expression = "B"
        datasource = { type = "__expr__", uid = "__expr__" }
        conditions = [{ evaluator = { type = "gt", params = [85] } }]
      })
    }

    labels         = { severity = "warning" }
    annotations    = { summary = "CPU usage above 85% on {{ $labels.instance }} ({{ humanize $values.B.Value }}%)" }
    no_data_state  = "OK"
    exec_err_state = "Error"
  }

  rule {
    name      = "NodeHighMemoryUsage"
    condition = "C"
    for       = "10m"

    data {
      ref_id         = "A"
      datasource_uid = local.prom_ds_uid
      relative_time_range {
        from = 600
        to   = 0
      }
      model = jsonencode({
        refId         = "A"
        datasource    = { type = "prometheus", uid = local.prom_ds_uid }
        expr          = "(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100"
        instant       = true
        range         = false
        intervalMs    = 1000
        maxDataPoints = 43200
      })
    }
    data {
      ref_id         = "B"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        refId      = "B"
        type       = "reduce"
        expression = "A"
        reducer    = "last"
        datasource = { type = "__expr__", uid = "__expr__" }
      })
    }
    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        refId      = "C"
        type       = "threshold"
        expression = "B"
        datasource = { type = "__expr__", uid = "__expr__" }
        conditions = [{ evaluator = { type = "gt", params = [90] } }]
      })
    }

    labels         = { severity = "warning" }
    annotations    = { summary = "Memory usage above 90% on {{ $labels.instance }} ({{ humanize $values.B.Value }}%)" }
    no_data_state  = "OK"
    exec_err_state = "Error"
  }
}

resource "grafana_rule_group" "storage" {
  name             = "storage"
  folder_uid       = grafana_folder.cluster_alerts.uid
  interval_seconds = 120

  rule {
    name      = "PVCUsageHigh"
    condition = "C"
    for       = "15m"

    data {
      ref_id         = "A"
      datasource_uid = local.prom_ds_uid
      relative_time_range {
        from = 600
        to   = 0
      }
      model = jsonencode({
        refId         = "A"
        datasource    = { type = "prometheus", uid = local.prom_ds_uid }
        expr          = "(kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) * 100"
        instant       = true
        range         = false
        intervalMs    = 1000
        maxDataPoints = 43200
      })
    }
    data {
      ref_id         = "B"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        refId      = "B"
        type       = "reduce"
        expression = "A"
        reducer    = "last"
        datasource = { type = "__expr__", uid = "__expr__" }
      })
    }
    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        refId      = "C"
        type       = "threshold"
        expression = "B"
        datasource = { type = "__expr__", uid = "__expr__" }
        conditions = [{ evaluator = { type = "gt", params = [85] } }]
      })
    }

    labels         = { severity = "warning" }
    annotations    = { summary = "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} is {{ humanize $values.B.Value }}% full" }
    no_data_state  = "OK"
    exec_err_state = "Error"
  }
}

# Watchdog: fires when the cluster stops shipping metrics. Unlike every rule
# above (no_data_state = "OK", so they go silent when there is no data), this one
# treats absence of data as the alarm. It complements the OnCall heartbeat: the
# heartbeat catches the whole node/network going down, this catches the metrics
# pipeline dying while the node is otherwise up (e.g. the scrape agent crashes).
resource "grafana_rule_group" "watchdog" {
  name             = "watchdog"
  folder_uid       = grafana_folder.cluster_alerts.uid
  interval_seconds = 60

  rule {
    name      = "MetricsPipelineDown"
    condition = "C"
    for       = "2m"

    data {
      ref_id         = "A"
      datasource_uid = local.prom_ds_uid
      relative_time_range {
        from = 300
        to   = 0
      }
      model = jsonencode({
        refId         = "A"
        datasource    = { type = "prometheus", uid = local.prom_ds_uid }
        expr          = "count(up)"
        instant       = true
        range         = false
        intervalMs    = 1000
        maxDataPoints = 43200
      })
    }
    data {
      ref_id         = "B"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        refId      = "B"
        type       = "reduce"
        expression = "A"
        reducer    = "last"
        datasource = { type = "__expr__", uid = "__expr__" }
      })
    }
    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        refId      = "C"
        type       = "threshold"
        expression = "B"
        datasource = { type = "__expr__", uid = "__expr__" }
        conditions = [{ evaluator = { type = "lt", params = [1] } }]
      })
    }

    labels         = { severity = "critical" }
    annotations    = { summary = "No metrics are reaching Grafana Cloud – cluster observability is down" }
    no_data_state  = "Alerting"
    exec_err_state = "Alerting"
  }
}
