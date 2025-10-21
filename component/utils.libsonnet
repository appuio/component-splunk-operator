// main template for splunk-operator
local commonAnnotations = {
  'syn.tools/source': 'https://github.com/projectsyn/component-splunk-operator.git',
};

local commonLabels = {
  'app.kubernetes.io/managed-by': 'commodore',
  'app.kubernetes.io/part-of': 'syn',
  'app.kubernetes.io/component': 'splunk',
};

local commonLabelsWithInstance(name) = commonLabels {
  'app.kubernetes.io/instance': name,
};

// Define outputs below
{
  commonAnnotations: commonAnnotations,
  commonLabels: commonLabels,
  commonLabelsWithInstance: commonLabelsWithInstance,
}
