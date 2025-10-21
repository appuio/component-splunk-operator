// main template for splunk-operator
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local splunk = import 'lib/splunk-operator.libsonnet';
local utils = import 'utils.libsonnet';
local inv = kap.inventory();

// The hiera parameters for the component
local params = inv.parameters.splunk_operator;

local namespacedName(name, namespace='') = {
  local namespaced = std.splitLimit(name, '/', 1),
  local ns = if namespace != '' then namespace else params.namespace,
  namespace: if std.length(namespaced) > 1 then namespaced[0] else ns,
  name: if std.length(namespaced) > 1 then namespaced[1] else namespaced[0],
};

// AppConfigs

local appConfigs(instance) = [
  {
    apiVersion: 'v1',
    kind: 'Secret',
    metadata: {
      annotations: utils.commonAnnotations,
      labels: utils.commonLabelsWithInstance(namespacedName(instance).name),
      name: 'splunk-appconfig-%s' % app,
      namespace: namespacedName(instance).namespace,
    },
    type: 'Opaque',
    data: params.instances[instance].appConfigs[app],
  }
  for app in std.objectFields(std.get(params.instances[instance], 'appConfigs', {}))
  if params.instances[instance].appConfigs[app] != null
];

// Standalone Resource

local patchImage = {
  spec: {
    image: '%(registry)s/%(repository)s:%(tag)s' % params.images.splunk,
  },
};

local patchServiceAccount(instance) = {
  spec: {
    serviceAccount: namespacedName(instance).name,
  },
};

local patchAppConfigs(instance) = {
  [if std.objectHas(params.instances[instance], 'appConfigs') then 'spec']: {
    volumes: [
      {
        name: std.strReplace(appConfig.metadata.name, 'splunk-appconfig-', ''),
        secret: {
          secretName: appConfig.metadata.name,
        },
      }
      for appConfig in appConfigs(instance)
      if appConfig != null
    ],
  },
};

local patchConfigSpecs(instance) = {
  [if std.objectHas(params.instances[instance], 'standalone') then 'spec']: params.instances[instance].standalone,
};

// Consecutively apply patches to result of previous apply.
local standalone(instance) = std.foldl(
  // we use std.mergePatch here, because this way we don't need
  // to make each patch object mergeable by suffixing all keys with a +.
  function(manifest, patch) std.mergePatch(manifest, patch),
  [
    // patchImage,
    patchAppConfigs(instance),
    patchServiceAccount(instance),
    patchConfigSpecs(instance),
  ],
  splunk.Standalone_v4(namespacedName(instance).name) {
    metadata+: {
      annotations: utils.commonAnnotations,
      labels: utils.commonLabelsWithInstance(namespacedName(instance).name),
    },
  }
);

// local instance(instanceName) = [
//   standalone(instanceName),
//   apps(instanceName),
//   serviceAccount(instanceName),
//   roleBinding(instanceName),
// ];

// Namespace

local namespace(instance) = {
  apiVersion: 'v1',
  kind: 'Namespace',
  metadata: {
    annotations: {
      'argocd.argoproj.io/sync-wave': '-50',
    } + utils.commonAnnotations,
    labels: utils.commonLabelsWithInstance(namespacedName(instance).name),
    name: namespacedName(instance).namespace,
  },
};

// RABC

local serviceAccount(instance) = {
  apiVersion: 'v1',
  kind: 'ServiceAccount',
  metadata: {
    annotations: utils.commonAnnotations,
    labels: utils.commonLabelsWithInstance(namespacedName(instance).name),
    name: standalone(instance).spec.serviceAccount,
    namespace: namespacedName(instance).namespace,
  },
};

local roleBinding(instance) = {
  apiVersion: 'rbac.authorization.k8s.io/v1',
  kind: 'RoleBinding',
  metadata: {
    annotations: utils.commonAnnotations,
    labels: utils.commonLabelsWithInstance(namespacedName(instance).name),
    name: 'splunk-standalone-%(name)s-nonroot-v2' % namespacedName(instance),
    namespace: namespacedName(instance).namespace,
  },
  roleRef: {
    apiGroup: 'rbac.authorization.k8s.io',
    kind: 'ClusterRole',
    name: 'system:openshift:scc:nonroot-v2',
  },
  subjects: [
    {
      kind: 'ServiceAccount',
      name: standalone(instance).spec.serviceAccount,
      namespace: serviceAccount(instance).metadata.namespace,
    },
  ],
};

// Define outputs below
{
  [if std.length(params.instances) > 0 then '50_standalone_%s' % std.strReplace(instance, '/', '_')]: [
    namespace(instance),
    standalone(instance),
    serviceAccount(instance),
    roleBinding(instance),
  ] + appConfigs(instance)
  for instance in std.objectFields(params.instances)
  if params.instances[instance] != null
}
