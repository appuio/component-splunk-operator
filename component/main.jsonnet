// main template for splunk-operator
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local operatorlib = import 'lib/openshift4-operators.libsonnet';

local inv = kap.inventory();
local params = inv.parameters.splunk_operator;

// Namespace

local namespace = kube.Namespace(params.namespace) {
  metadata+: {
    annotations+: {
      'openshift.io/node-selector': '',
      'argocd.argoproj.io/sync-wave': '-100',
    },
    labels+: {
      'openshift.io/cluster-monitoring': 'true',
    },
  },
};

// OperatorGroup

local operatorGroup = operatorlib.OperatorGroup('splunk-operator') {
  metadata+: {
    annotations+: {
      'argocd.argoproj.io/sync-wave': '-90',
    },
    namespace: params.namespace,
  },
};

// Subscriptions

local subscription = operatorlib.namespacedSubscription(
  params.namespace,
  'splunk-operator',
  params.channel,
  'certified-operators'
) {
  metadata+: {
    annotations+: {
      'argocd.argoproj.io/sync-wave': '-80',
    },
  },
  spec+: {
    config+: {
      env: [ {
        name: 'SPLUNK_GENERAL_TERMS',
        value: '--accept-sgt-current-at-splunk-com',
      } ],
      resources: params.operatorResources.splunk,
    },
  },
};

// Define outputs below
{
  '00_namespace': namespace,
  '10_operator_group': operatorGroup,
  '20_subscriptions': subscription,
}
