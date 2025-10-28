/**
 * \file splunk.libsonnet
 * \brief Helpers to create Splunk CRs.
 */

local com = import 'lib/commodore.libjsonnet';
local groupVersionPrefix = 'enterprise.splunk.com/';

/**
  * \brief Helper to create Standalone objects.
  *
  * \arg The name of the Standalone resource.
  * \arg The version of the Splunk apiGroup, defaults to 'v4'.
  * \return A Standalone object.
  */
local standalone(name, v='v4') = {
  apiVersion: groupVersionPrefix + v,
  kind: 'Standalone',
  metadata: {
    labels: {
      'app.kubernetes.io/name': name,
    },
    name: name,
  },
};

{
  Standalone_v4(name): standalone(name, 'v4'),
}
