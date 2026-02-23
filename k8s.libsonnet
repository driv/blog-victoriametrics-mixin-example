local mixin = import 'main.libsonnet';

// Helper to sanitize names for K8s resources
local sanitizeName(s) = std.strReplace(std.asciiLower(s), '_', '-');

{
  // WRAPPER: VMRule (VictoriaMetrics Operator CRD)
  local vmRule(name, groups) = {
    apiVersion: 'operator.victoriametrics.com/v1beta1',
    kind: 'VMRule',
    metadata: {
      name: name,
      namespace: 'monitoring', // Make this configurable if needed
    },
    spec: {
      groups: groups,
    },
  },

  // WRAPPER: ConfigMap (Grafana Dashboards)
  local dashboardCm(name, content) = {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'grafana-dashboard-' + sanitizeName(name),
      namespace: 'monitoring',
      labels: {
        grafana_dashboard: '1', // Label for the sidecar
      },
    },
    data: {
      [name + '.json']: std.toString(content),
    },
  },

  // OUTPUT LIST
  apiVersion: 'v1',
  kind: 'List',
  items: [
    // 1. Alert Rules
    vmRule('mixin-alerts', mixin.prometheusAlerts.groups),
    
    // 2. Recording Rules
    vmRule('mixin-rules', mixin.prometheusRules.groups),
  ] + [
    // 3. Dashboards (iterating over all dashboards in the mixin)
    dashboardCm(name, mixin.grafanaDashboards[name])
    for name in std.objectFields(mixin.grafanaDashboards)
  ],
}
