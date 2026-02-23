local kubernetes = import 'kubernetes-mixin/mixin.libsonnet';

kubernetes {
  _config+:: {
    // Overrides for VictoriaMetrics K8s Stack
    // Adjust these selectors if your label names differ.
    // Standard VM stack often uses these job names:
    
    cadvisorSelector: 'job="kubernetes-cadvisor"',
    kubeletSelector: 'job="kubernetes-nodes"',
    kubeStateMetricsSelector: 'job="kube-state-metrics"',
    nodeExporterSelector: 'job="node-exporter"',
    kubeSchedulerSelector: 'job="kube-scheduler"',
    kubeControllerManagerSelector: 'job="kube-controller-manager"',
    kubeApiserverSelector: 'job="kubernetes-apiservers"',
    
    // Some setups might prefix with namespace or use different label keys
    // e.g., namespaceSelector: 'namespace="monitoring"',
  },
}
